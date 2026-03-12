import json
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional, List

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
                # Create table with role_level column
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS coaching_profiles (
                        user_id TEXT PRIMARY KEY,
                        profile_json JSONB NOT NULL,
                        role_level TEXT DEFAULT NULL,
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """)
                # Add role_level column if table exists (migration path)
                cur.execute("""
                    DO $$
                    BEGIN
                        IF NOT EXISTS (
                            SELECT 1 FROM information_schema.columns
                            WHERE table_name = 'coaching_profiles' AND column_name = 'role_level'
                        ) THEN
                            ALTER TABLE coaching_profiles ADD COLUMN role_level TEXT;
                        END IF;
                    END $$;
                """)
            conn.commit()

    def _get_conn(self):
        return psycopg.connect(self.database_url)

    def get_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT profile_json, role_level FROM coaching_profiles WHERE user_id = %s",
                    (user_id,),
                )
                row = cur.fetchone()
        if not row:
            return None
        profile = row["profile_json"]
        # Merge role_level if set
        if row.get("role_level"):
            profile = {**profile, "role_level": row["role_level"]}
        return profile

    def save_profile(self, user_id: str, profile: Dict[str, Any], role_level: Optional[str] = None) -> None:
        now = datetime.now(timezone.utc)
        with self._get_conn() as conn:
            with conn.cursor() as cur:
                if role_level:
                    # Merge role_level into profile_json and set column
                    profile_with_role = {**profile, "role_level": role_level}
                    cur.execute(
                        """INSERT INTO coaching_profiles (user_id, profile_json, role_level, updated_at)
                           VALUES (%s, %s, %s, %s)
                           ON CONFLICT (user_id)
                           DO UPDATE SET profile_json = %s, role_level = %s, updated_at = %s""",
                        (user_id, json.dumps(profile_with_role), role_level, now,
                         json.dumps(profile_with_role), role_level, now),
                    )
                else:
                    # Existing behavior - preserve role_level if it exists
                    cur.execute(
                        """INSERT INTO coaching_profiles (user_id, profile_json, updated_at)
                           VALUES (%s, %s, %s)
                           ON CONFLICT (user_id)
                           DO UPDATE SET profile_json = coaching_profiles.profile_json || %s::jsonb, updated_at = %s""",
                        (user_id, json.dumps(profile), now, json.dumps(profile), now),
                    )
            conn.commit()

    def update_role_level(self, user_id: str, role_level: str) -> None:
        """Update only the role_level field. Creates profile row if it doesn't exist."""
        now = datetime.now(timezone.utc)
        with self._get_conn() as conn:
            with conn.cursor() as cur:
                # Use INSERT ... ON CONFLICT to handle both new and existing users
                cur.execute("""
                    INSERT INTO coaching_profiles (user_id, profile_json, role_level, updated_at)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (user_id)
                    DO UPDATE SET
                        role_level = EXCLUDED.role_level,
                        profile_json = jsonb_set(
                            COALESCE(profile_json, '{}'::jsonb),
                            '{role_level}',
                            %s::jsonb
                        ),
                        updated_at = EXCLUDED.updated_at
                """, (user_id, json.dumps({"role_level": role_level}), role_level, now,
                     json.dumps(role_level), now))
            conn.commit()

    def get_role_level(self, user_id: str) -> Optional[str]:
        """Get only the role_level for a user."""
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT role_level FROM coaching_profiles WHERE user_id = %s",
                    (user_id,),
                )
                row = cur.fetchone()
        if not row:
            return None
        return row.get("role_level")


_profile_store: Optional[ProfileStore] = None


def get_profile_store() -> ProfileStore:
    global _profile_store
    if _profile_store is None:
        _profile_store = ProfileStore()
    return _profile_store
