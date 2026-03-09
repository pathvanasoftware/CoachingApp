from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Sequence

from fastapi import HTTPException


@dataclass(frozen=True)
class EntitlementSnapshot:
    seat_tier: str
    daily_session_limit: int
    can_use_voice: bool
    can_use_session_summary: bool
    allowed_personas: Optional[Sequence[str]]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "seat_tier": self.seat_tier,
            "daily_session_limit": self.daily_session_limit,
            "can_use_voice": self.can_use_voice,
            "can_use_session_summary": self.can_use_session_summary,
            "allowed_personas": list(self.allowed_personas) if self.allowed_personas is not None else None,
        }


_STARTER_PERSONAS = ("direct_challenger",)

_PLAN_MATRIX: Dict[str, EntitlementSnapshot] = {
    "starter": EntitlementSnapshot(
        seat_tier="starter",
        daily_session_limit=5,
        can_use_voice=False,
        can_use_session_summary=False,
        allowed_personas=_STARTER_PERSONAS,
    ),
    "professional": EntitlementSnapshot(
        seat_tier="professional",
        daily_session_limit=15,
        can_use_voice=True,
        can_use_session_summary=True,
        allowed_personas=None,
    ),
    "executive": EntitlementSnapshot(
        seat_tier="executive",
        daily_session_limit=50,
        can_use_voice=True,
        can_use_session_summary=True,
        allowed_personas=None,
    ),
}


class EntitlementService:
    def __init__(self, user_repo=None, session_repo=None):
        self.user_repo = user_repo
        self.session_repo = session_repo

    def _resolve_user_repo(self):
        if self.user_repo is not None:
            return self.user_repo

        from app.services.auth import user_service

        self.user_repo = user_service
        return self.user_repo

    def _resolve_session_repo(self):
        if self.session_repo is not None:
            return self.session_repo

        from app.services.sessions import session_service

        self.session_repo = session_service
        return self.session_repo

    def get_snapshot(self, user_id: str) -> EntitlementSnapshot:
        user = self._resolve_user_repo().get_user_by_id(user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        seat_tier = getattr(user, "seat_tier", "starter") or "starter"
        return _PLAN_MATRIX.get(seat_tier, _PLAN_MATRIX["starter"])

    def describe(self, user_id: str) -> Dict[str, Any]:
        snapshot = self.get_snapshot(user_id)
        sessions_started_today = self._sessions_started_today(user_id)
        return {
            **snapshot.to_dict(),
            "sessions_started_today": sessions_started_today,
            "remaining_sessions_today": max(0, snapshot.daily_session_limit - sessions_started_today),
        }

    def assert_can_start_session(self, user_id: str, *, persona: str, input_mode: str) -> None:
        snapshot = self.get_snapshot(user_id)

        if input_mode == "voice" and not snapshot.can_use_voice:
            raise HTTPException(
                status_code=403,
                detail="Voice coaching requires Ascendra Pro.",
            )

        if snapshot.allowed_personas is not None and persona not in snapshot.allowed_personas:
            raise HTTPException(
                status_code=403,
                detail="This coaching persona requires Ascendra Pro.",
            )

        started_today = self._sessions_started_today(user_id)
        if started_today >= snapshot.daily_session_limit:
            raise HTTPException(
                status_code=429,
                detail="You have reached your session limit for today.",
            )

    def assert_can_generate_session_summary(self, user_id: str) -> None:
        snapshot = self.get_snapshot(user_id)
        if not snapshot.can_use_session_summary:
            raise HTTPException(
                status_code=403,
                detail="Session summaries require Ascendra Pro.",
            )

    def can_generate_session_summary(self, user_id: str) -> bool:
        return self.get_snapshot(user_id).can_use_session_summary

    def _sessions_started_today(self, user_id: str) -> int:
        now = datetime.now(timezone.utc)
        since = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
        return self._resolve_session_repo().count_sessions_started_since(user_id, since)


entitlement_service = EntitlementService()
