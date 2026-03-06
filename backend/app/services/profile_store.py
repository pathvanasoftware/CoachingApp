import json
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import psycopg
from psycopg.rows import dict_row

logger = logging.getLogger(__name__)


class ProfileStore:
    def __init__(self, database_url: Optional[str] = None):
        self.database_url = database_url or os.getenv("DATABASE_URL")
        if not self.database_url:
            raise RuntimeError("DATABASE_URL environment variable is required for profile storage")
        self._ensure_db()

    def _ensure_db(self):
        with psycopg.connect(self.database_url) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS coaching_profiles (
                        user_id TEXT PRIMARY KEY,
                        profile_json JSONB NOT NULL,
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """)
            conn.commit()

    def _get_conn(self):
        return psycopg.connect(self.database_url)

    def get_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT profile_json FROM coaching_profiles WHERE user_id = %s",
                    (user_id,),
                )
                row = cur.fetchone()
        if not row:
            return None
        return row["profile_json"]

    def save_profile(self, user_id: str, profile: Dict[str, Any]) -> None:
        now = datetime.now(timezone.utc)
        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """INSERT INTO coaching_profiles (user_id, profile_json, updated_at)
                       VALUES (%s, %s, %s)
                       ON CONFLICT (user_id)
                       DO UPDATE SET profile_json = %s, updated_at = %s""",
                    (user_id, json.dumps(profile), now, json.dumps(profile), now),
                )
            conn.commit()


_profile_store: Optional[ProfileStore] = None


def get_profile_store() -> ProfileStore:
    global _profile_store
    if _profile_store is None:
        _profile_store = ProfileStore()
    return _profile_store
