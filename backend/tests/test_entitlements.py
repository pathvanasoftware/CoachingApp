from dataclasses import dataclass
from datetime import datetime, timezone

import pytest
from fastapi import HTTPException

from app.services.entitlements import EntitlementService


@dataclass
class _StubUser:
    id: str
    seat_tier: str


class _StubUserRepo:
    def __init__(self, seat_tier: str):
        self.user = _StubUser(id="user-1", seat_tier=seat_tier)

    def get_user_by_id(self, user_id: str):
        if user_id != self.user.id:
            return None
        return self.user


class _StubSessionRepo:
    def __init__(self, sessions_started_today: int = 0):
        self.sessions_started_today = sessions_started_today
        self.last_since = None

    def count_sessions_started_since(self, user_id: str, started_after: datetime) -> int:
        self.last_since = started_after
        assert user_id == "user-1"
        return self.sessions_started_today


def test_starter_blocks_voice_and_second_persona():
    service = EntitlementService(
        user_repo=_StubUserRepo("starter"),
        session_repo=_StubSessionRepo(),
    )

    with pytest.raises(HTTPException) as voice_error:
        service.assert_can_start_session(
            "user-1",
            persona="direct_challenger",
            input_mode="voice",
        )
    assert voice_error.value.status_code == 403

    with pytest.raises(HTTPException) as persona_error:
        service.assert_can_start_session(
            "user-1",
            persona="supportive_strategist",
            input_mode="text",
        )
    assert persona_error.value.status_code == 403


def test_starter_enforces_daily_session_limit():
    service = EntitlementService(
        user_repo=_StubUserRepo("starter"),
        session_repo=_StubSessionRepo(sessions_started_today=5),
    )

    with pytest.raises(HTTPException) as exc:
        service.assert_can_start_session(
            "user-1",
            persona="direct_challenger",
            input_mode="text",
        )

    assert exc.value.status_code == 429


def test_professional_has_premium_access():
    sessions = _StubSessionRepo(sessions_started_today=2)
    service = EntitlementService(
        user_repo=_StubUserRepo("professional"),
        session_repo=sessions,
    )

    service.assert_can_start_session(
        "user-1",
        persona="supportive_strategist",
        input_mode="voice",
    )
    service.assert_can_generate_session_summary("user-1")

    description = service.describe("user-1")
    assert description["seat_tier"] == "professional"
    assert description["can_use_voice"] is True
    assert description["can_use_session_summary"] is True
    assert description["sessions_started_today"] == 2
    assert description["remaining_sessions_today"] == 13
    assert sessions.last_since is not None
    assert sessions.last_since.tzinfo == timezone.utc
    assert sessions.last_since.hour == 0
    assert sessions.last_since.minute == 0
    assert sessions.last_since.second == 0
    assert sessions.last_since.microsecond == 0
