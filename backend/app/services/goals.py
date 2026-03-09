import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import psycopg
from psycopg.rows import dict_row


class GoalService:
    def __init__(self, database_url: Optional[str] = None):
        self.database_url = database_url or os.getenv("DATABASE_URL")
        if not self.database_url:
            raise RuntimeError("DATABASE_URL environment variable is required for goal persistence")

        self._ensure_db()

    def _get_conn(self):
        return psycopg.connect(self.database_url)

    def _ensure_db(self):
        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS goals (
                        id TEXT PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        title TEXT NOT NULL,
                        description TEXT DEFAULT '',
                        status TEXT DEFAULT 'active',
                        progress DOUBLE PRECISION DEFAULT 0,
                        target_date TIMESTAMPTZ,
                        milestones JSONB DEFAULT '[]'::jsonb,
                        related_session_ids JSONB DEFAULT '[]'::jsonb,
                        created_at TIMESTAMPTZ NOT NULL,
                        updated_at TIMESTAMPTZ NOT NULL
                    )
                    """
                )
                cur.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_goals_user_updated
                    ON goals (user_id, updated_at DESC)
                    """
                )
            conn.commit()

    def list_goals(self, user_id: str) -> List[Dict[str, Any]]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    """
                    SELECT *
                    FROM goals
                    WHERE user_id = %s
                    ORDER BY created_at DESC
                    """,
                    (user_id,),
                )
                rows = cur.fetchall()
        return [self._row_to_goal(row) for row in rows]

    def get_goal(self, goal_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    """
                    SELECT *
                    FROM goals
                    WHERE id = %s AND user_id = %s
                    """,
                    (goal_id, user_id),
                )
                row = cur.fetchone()
        if not row:
            return None
        return self._row_to_goal(row)

    def create_goal(
        self,
        *,
        id: str,
        user_id: str,
        title: str,
        description: str = "",
        status: str = "active",
        progress: float = 0.0,
        target_date: Optional[datetime] = None,
        milestones: Optional[List[Dict[str, Any]]] = None,
        related_session_ids: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        now = datetime.now(timezone.utc)
        normalized_milestones = self._normalize_milestones(milestones or [])
        normalized_progress = self._calculate_progress(status, progress, normalized_milestones)
        normalized_related_sessions = related_session_ids or []

        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO goals (
                        id,
                        user_id,
                        title,
                        description,
                        status,
                        progress,
                        target_date,
                        milestones,
                        related_session_ids,
                        created_at,
                        updated_at
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s::jsonb, %s, %s)
                    """,
                    (
                        id,
                        user_id,
                        title,
                        description,
                        status,
                        normalized_progress,
                        target_date,
                        json.dumps(normalized_milestones),
                        json.dumps(normalized_related_sessions),
                        now,
                        now,
                    ),
                )
            conn.commit()

        return self.get_goal(id, user_id)

    def update_goal(
        self,
        goal_id: str,
        user_id: str,
        *,
        title: str,
        description: str,
        status: str,
        progress: float,
        target_date: Optional[datetime],
        milestones: List[Dict[str, Any]],
        related_session_ids: List[str],
    ) -> Optional[Dict[str, Any]]:
        normalized_milestones = self._normalize_milestones(milestones)
        normalized_progress = self._calculate_progress(status, progress, normalized_milestones)
        updated_at = datetime.now(timezone.utc)

        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE goals
                    SET
                        title = %s,
                        description = %s,
                        status = %s,
                        progress = %s,
                        target_date = %s,
                        milestones = %s::jsonb,
                        related_session_ids = %s::jsonb,
                        updated_at = %s
                    WHERE id = %s AND user_id = %s
                    """,
                    (
                        title,
                        description,
                        status,
                        normalized_progress,
                        target_date,
                        json.dumps(normalized_milestones),
                        json.dumps(related_session_ids),
                        updated_at,
                        goal_id,
                        user_id,
                    ),
                )
                updated_rows = cur.rowcount
            conn.commit()

        if updated_rows == 0:
            return None
        return self.get_goal(goal_id, user_id)

    def delete_goal(self, goal_id: str, user_id: str) -> bool:
        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    DELETE FROM goals
                    WHERE id = %s AND user_id = %s
                    """,
                    (goal_id, user_id),
                )
                deleted_rows = cur.rowcount
            conn.commit()
        return deleted_rows > 0

    def _normalize_milestones(self, milestones: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        normalized: List[Dict[str, Any]] = []
        for milestone in milestones:
            completed_at = milestone.get("completed_at")
            if isinstance(completed_at, datetime):
                completed_at = completed_at.isoformat()

            normalized.append(
                {
                    "id": milestone["id"],
                    "title": milestone["title"],
                    "is_completed": bool(milestone.get("is_completed", False)),
                    "completed_at": completed_at,
                }
            )
        return normalized

    def _calculate_progress(
        self,
        status: str,
        progress: float,
        milestones: List[Dict[str, Any]],
    ) -> float:
        if status == "completed":
            return 1.0
        if milestones:
            completed = sum(1 for milestone in milestones if milestone.get("is_completed"))
            return completed / len(milestones)
        return max(0.0, min(progress, 1.0))

    def _row_to_goal(self, row: Dict[str, Any]) -> Dict[str, Any]:
        milestones = row.get("milestones") or []
        if isinstance(milestones, str):
            milestones = json.loads(milestones)

        related_session_ids = row.get("related_session_ids") or []
        if isinstance(related_session_ids, str):
            related_session_ids = json.loads(related_session_ids)

        return {
            "id": row["id"],
            "user_id": row["user_id"],
            "title": row["title"],
            "description": row.get("description") or "",
            "status": row.get("status") or "active",
            "progress": float(row.get("progress") or 0.0),
            "target_date": row.get("target_date"),
            "milestones": milestones,
            "related_session_ids": related_session_ids,
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        }


goal_service = GoalService()
