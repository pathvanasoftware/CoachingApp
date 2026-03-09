import json
import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import psycopg
from psycopg.rows import dict_row


class SessionService:
    def __init__(self, database_url: Optional[str] = None):
        self.database_url = database_url or os.getenv("DATABASE_URL")
        if not self.database_url:
            raise RuntimeError("DATABASE_URL environment variable is required for session persistence")

        self._ensure_db()

    def _get_conn(self):
        return psycopg.connect(self.database_url)

    def _ensure_db(self):
        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS sessions (
                        id TEXT PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        persona TEXT NOT NULL,
                        session_type TEXT NOT NULL,
                        input_mode TEXT NOT NULL,
                        started_at TIMESTAMPTZ NOT NULL,
                        ended_at TIMESTAMPTZ,
                        summary TEXT,
                        session_summary JSONB,
                        duration_seconds INTEGER,
                        message_count INTEGER DEFAULT 0,
                        goal_ids JSONB DEFAULT '[]'::jsonb
                    )
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE sessions
                    ADD COLUMN IF NOT EXISTS session_summary JSONB
                    """
                )
                cur.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_sessions_user_started
                    ON sessions (user_id, started_at DESC)
                    """
                )
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS messages (
                        id TEXT PRIMARY KEY,
                        session_id TEXT NOT NULL,
                        role TEXT NOT NULL,
                        content TEXT NOT NULL,
                        timestamp TIMESTAMPTZ NOT NULL,
                        is_streaming BOOLEAN DEFAULT FALSE,
                        diagnostics JSONB,
                        status TEXT DEFAULT 'sent'
                    )
                    """
                )
                cur.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_messages_session_timestamp
                    ON messages (session_id, timestamp ASC)
                    """
                )
            conn.commit()

    def create_session(
        self,
        *,
        user_id: str,
        persona: str,
        session_type: str,
        input_mode: str,
    ) -> Dict[str, Any]:
        session_id = str(uuid.uuid4())
        started_at = datetime.now(timezone.utc)

        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO sessions (
                        id,
                        user_id,
                        persona,
                        session_type,
                        input_mode,
                        started_at,
                        message_count,
                        goal_ids
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, 0, '[]'::jsonb)
                    """,
                    (session_id, user_id, persona, session_type, input_mode, started_at),
                )
            conn.commit()

        return self.get_session(session_id, user_id)

    def get_session(self, session_id: str, user_id: str) -> Optional[Dict[str, Any]]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    """
                    SELECT *
                    FROM sessions
                    WHERE id = %s AND user_id = %s
                    """,
                    (session_id, user_id),
                )
                row = cur.fetchone()
        if not row:
            return None
        return self._row_to_session(row)

    def get_session_by_id(self, session_id: str) -> Optional[Dict[str, Any]]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    """
                    SELECT *
                    FROM sessions
                    WHERE id = %s
                    """,
                    (session_id,),
                )
                row = cur.fetchone()
        if not row:
            return None
        return self._row_to_session(row)

    def list_sessions(self, user_id: str) -> List[Dict[str, Any]]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    """
                    SELECT *
                    FROM sessions
                    WHERE user_id = %s
                    ORDER BY started_at DESC
                    """,
                    (user_id,),
                )
                rows = cur.fetchall()
        return [self._row_to_session(row) for row in rows]

    def end_session(
        self,
        session_id: str,
        user_id: str,
        *,
        summary: Optional[str] = None,
        summary_payload: Optional[Dict[str, Any]] = None,
    ) -> Optional[Dict[str, Any]]:
        existing = self.get_session(session_id, user_id)
        if not existing:
            return None

        ended_at = datetime.now(timezone.utc)
        duration_seconds = int((ended_at - self._ensure_aware(existing["started_at"])).total_seconds())
        final_summary = summary or existing.get("summary") or f"Session completed with {existing.get('message_count', 0)} messages exchanged."
        final_summary_payload = summary_payload or existing.get("session_summary")

        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE sessions
                    SET ended_at = %s, duration_seconds = %s, summary = %s, session_summary = %s::jsonb
                    WHERE id = %s AND user_id = %s
                    """,
                    (
                        ended_at,
                        duration_seconds,
                        final_summary,
                        json.dumps(final_summary_payload) if final_summary_payload is not None else None,
                        session_id,
                        user_id,
                    ),
                )
            conn.commit()

        return self.get_session(session_id, user_id)

    def delete_session(self, session_id: str, user_id: str) -> bool:
        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "DELETE FROM messages WHERE session_id = %s",
                    (session_id,),
                )
                cur.execute(
                    "DELETE FROM sessions WHERE id = %s AND user_id = %s",
                    (session_id, user_id),
                )
                deleted_rows = cur.rowcount
            conn.commit()
        return deleted_rows > 0

    def list_messages(self, session_id: str, user_id: str) -> List[Dict[str, Any]]:
        session = self.get_session(session_id, user_id)
        if not session:
            return []

        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    """
                    SELECT *
                    FROM messages
                    WHERE session_id = %s
                    ORDER BY timestamp ASC
                    """,
                    (session_id,),
                )
                rows = cur.fetchall()
        return [self._row_to_message(row) for row in rows]

    def create_message(
        self,
        *,
        session_id: str,
        role: str,
        content: str,
        diagnostics: Optional[Dict[str, Any]] = None,
        status: str = "sent",
    ) -> Dict[str, Any]:
        message_id = str(uuid.uuid4())
        timestamp = datetime.now(timezone.utc)

        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO messages (
                        id,
                        session_id,
                        role,
                        content,
                        timestamp,
                        is_streaming,
                        diagnostics,
                        status
                    )
                    VALUES (%s, %s, %s, %s, %s, FALSE, %s::jsonb, %s)
                    """,
                    (
                        message_id,
                        session_id,
                        role,
                        content,
                        timestamp,
                        json.dumps(diagnostics) if diagnostics is not None else None,
                        status,
                    ),
                )
                cur.execute(
                    """
                    UPDATE sessions
                    SET message_count = (
                        SELECT COUNT(*)::INTEGER FROM messages WHERE session_id = %s
                    )
                    WHERE id = %s
                    """,
                    (session_id, session_id),
                )
            conn.commit()

        return self.get_message(message_id)

    def get_message(self, message_id: str) -> Optional[Dict[str, Any]]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    """
                    SELECT *
                    FROM messages
                    WHERE id = %s
                    """,
                    (message_id,),
                )
                row = cur.fetchone()
        if not row:
            return None
        return self._row_to_message(row)

    def record_turn(
        self,
        *,
        session_id: str,
        user_content: str,
        assistant_content: str,
        assistant_diagnostics: Optional[Dict[str, Any]] = None,
    ) -> None:
        self.create_message(
            session_id=session_id,
            role="user",
            content=user_content,
            diagnostics=None,
            status="sent",
        )
        self.create_message(
            session_id=session_id,
            role="assistant",
            content=assistant_content,
            diagnostics=assistant_diagnostics,
            status="sent",
        )

    def sync_goal_links(self, *, user_id: str, goal_id: str, related_session_ids: List[str]) -> None:
        desired_session_ids = set(related_session_ids)

        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    """
                    SELECT id, goal_ids
                    FROM sessions
                    WHERE user_id = %s
                    """,
                    (user_id,),
                )
                rows = cur.fetchall()

                for row in rows:
                    current_goal_ids = row.get("goal_ids") or []
                    if isinstance(current_goal_ids, str):
                        current_goal_ids = json.loads(current_goal_ids)

                    current_goal_ids = [value for value in current_goal_ids if value != goal_id]
                    if row["id"] in desired_session_ids:
                        current_goal_ids.append(goal_id)

                    cur.execute(
                        """
                        UPDATE sessions
                        SET goal_ids = %s::jsonb
                        WHERE id = %s AND user_id = %s
                        """,
                        (json.dumps(current_goal_ids), row["id"], user_id),
                    )
            conn.commit()

    def _row_to_session(self, row: Dict[str, Any]) -> Dict[str, Any]:
        goal_ids = row.get("goal_ids") or []
        if isinstance(goal_ids, str):
            goal_ids = json.loads(goal_ids)

        session_summary = row.get("session_summary")
        if isinstance(session_summary, str):
            session_summary = json.loads(session_summary)

        return {
            "id": row["id"],
            "user_id": row["user_id"],
            "persona": row["persona"],
            "session_type": row["session_type"],
            "input_mode": row["input_mode"],
            "started_at": row["started_at"],
            "ended_at": row.get("ended_at"),
            "summary": row.get("summary"),
            "session_summary": session_summary,
            "duration_seconds": row.get("duration_seconds"),
            "message_count": int(row.get("message_count") or 0),
            "goal_ids": goal_ids,
        }

    def _row_to_message(self, row: Dict[str, Any]) -> Dict[str, Any]:
        diagnostics = row.get("diagnostics")
        if isinstance(diagnostics, str):
            diagnostics = json.loads(diagnostics)

        return {
            "id": row["id"],
            "session_id": row["session_id"],
            "role": row["role"],
            "content": row["content"],
            "timestamp": row["timestamp"],
            "is_streaming": bool(row.get("is_streaming")),
            "diagnostics": diagnostics,
            "status": row.get("status") or "sent",
        }

    def _ensure_aware(self, value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value


session_service = SessionService()
