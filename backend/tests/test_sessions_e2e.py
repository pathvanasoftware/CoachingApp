import os

import psycopg
import pytest
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient

from app.routers.auth import router as auth_router
from app.routers.sessions import router as sessions_router
from app.services.auth import UserService
from app.services.sessions import SessionService


@pytest.fixture
def test_db_url():
    url = os.getenv("DATABASE_URL")
    if not url:
        pytest.skip("DATABASE_URL not set - skipping PostgreSQL tests")
    return url


@pytest.fixture
def clean_db(test_db_url):
    with psycopg.connect(test_db_url) as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM messages")
            cur.execute("DELETE FROM sessions")
            cur.execute("DELETE FROM users")
        conn.commit()
    yield test_db_url
    with psycopg.connect(test_db_url) as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM messages")
            cur.execute("DELETE FROM sessions")
            cur.execute("DELETE FROM users")
        conn.commit()


@pytest.fixture
def app(clean_db):
    test_user_service = UserService(database_url=clean_db)
    test_session_service = SessionService(database_url=clean_db)

    app = FastAPI(title="Test App", version="1.0.0")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    from app.routers import auth as auth_router_module
    from app.routers import sessions as sessions_router_module

    original_user_service = auth_router_module.user_service
    original_session_service = sessions_router_module.session_service
    auth_router_module.user_service = test_user_service
    sessions_router_module.session_service = test_session_service

    app.include_router(auth_router, prefix="/api/auth", tags=["Auth"])
    app.include_router(sessions_router, prefix="/api", tags=["Sessions"])

    yield app

    auth_router_module.user_service = original_user_service
    sessions_router_module.session_service = original_session_service


@pytest.fixture
def client(app):
    return TestClient(app)


@pytest.fixture
def auth_context(client):
    register_response = client.post(
        "/api/auth/register",
        json={
            "email": "sessions@example.com",
            "password": "password123",
            "full_name": "Sessions User",
        },
    )
    body = register_response.json()
    return {
        "user_id": body["user"]["id"],
        "headers": {"Authorization": f"Bearer {body['access_token']}"},
    }


def test_start_list_and_end_session(client, auth_context):
    start_response = client.post(
        "/api/sessions",
        headers=auth_context["headers"],
        json={
            "user_id": auth_context["user_id"],
            "persona": "direct_challenger",
            "session_type": "freeform",
            "input_mode": "text",
        },
    )
    assert start_response.status_code == 200
    session = start_response.json()
    assert session["user_id"] == auth_context["user_id"]
    assert session["ended_at"] is None

    list_response = client.get("/api/sessions", headers=auth_context["headers"])
    assert list_response.status_code == 200
    sessions = list_response.json()
    assert len(sessions) == 1
    assert sessions[0]["id"] == session["id"]

    end_response = client.post(
        f"/api/sessions/{session['id']}/end",
        headers=auth_context["headers"],
        json={"session_id": session["id"]},
    )
    assert end_response.status_code == 200
    ended = end_response.json()
    assert ended["ended_at"] is not None
    assert ended["summary"]


def test_messages_round_trip(client, auth_context, monkeypatch):
    start_response = client.post(
        "/api/sessions",
        headers=auth_context["headers"],
        json={
            "user_id": auth_context["user_id"],
            "persona": "supportive_strategist",
            "session_type": "check_in",
            "input_mode": "text",
        },
    )
    session_id = start_response.json()["id"]

    from app.routers import sessions as sessions_router_module

    async def _fake_llm(_request):
        class _Result:
            response = "Let's make the next step concrete."
            style_used = "strategic"
            emotion_detected = "neutral"
            goal_link = "leadership_effectiveness"
            goal_anchor = None
            goal_hierarchy = None
            progressive_skill_building = None
            outcome_prediction = None
            recommended_style_shift = None

        return _Result()

    monkeypatch.setattr(sessions_router_module, "get_coaching_response", _fake_llm)
    monkeypatch.setattr(sessions_router_module, "_require_llm_or_503", lambda: None)

    send_response = client.post(
        f"/api/sessions/{session_id}/messages",
        headers=auth_context["headers"],
        json={
            "session_id": session_id,
            "content": "I need help prioritizing this week.",
            "role": "user",
        },
    )
    assert send_response.status_code == 200
    assistant_message = send_response.json()
    assert assistant_message["role"] == "assistant"
    assert "next step" in assistant_message["content"].lower()

    messages_response = client.get(
        f"/api/sessions/{session_id}/messages",
        headers=auth_context["headers"],
    )
    assert messages_response.status_code == 200
    messages = messages_response.json()
    assert len(messages) == 2
    assert messages[0]["role"] == "user"
    assert messages[1]["role"] == "assistant"


def test_end_session_generates_llm_summary(client, auth_context, monkeypatch):
    start_response = client.post(
        "/api/sessions",
        headers=auth_context["headers"],
        json={
            "user_id": auth_context["user_id"],
            "persona": "supportive_strategist",
            "session_type": "check_in",
            "input_mode": "text",
        },
    )
    session_id = start_response.json()["id"]

    from app.routers import sessions as sessions_router_module

    test_session_service = sessions_router_module.session_service
    test_session_service.record_turn(
        session_id=session_id,
        user_content="I need to tighten my team updates.",
        assistant_content="Let's make your updates shorter and outcome-focused.",
        assistant_diagnostics={},
    )

    async def _fake_summary(messages, user_id):
        assert user_id == auth_context["user_id"]
        assert len(messages) == 2
        return {
            "summary": "Clarified how to make leadership updates shorter and more outcome-focused.",
            "key_insights": [],
            "action_items": [],
            "progress_made": "",
            "recommended_next_steps": [],
        }

    monkeypatch.setattr(sessions_router_module, "generate_session_summary", _fake_summary)
    monkeypatch.setattr(sessions_router_module, "_anthropic_available", lambda: True)

    end_response = client.post(
        f"/api/sessions/{session_id}/end",
        headers=auth_context["headers"],
        json={"session_id": session_id},
    )
    assert end_response.status_code == 200
    ended = end_response.json()
    assert ended["summary"] == "Clarified how to make leadership updates shorter and more outcome-focused."
