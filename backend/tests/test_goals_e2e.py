import os

import psycopg
import pytest
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient

from app.routers.auth import router as auth_router
from app.routers.goals import router as goals_router
from app.services.auth import UserService
from app.services.goals import GoalService
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
            cur.execute("DELETE FROM goals")
            cur.execute("DELETE FROM users")
        conn.commit()
    yield test_db_url
    with psycopg.connect(test_db_url) as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM messages")
            cur.execute("DELETE FROM sessions")
            cur.execute("DELETE FROM goals")
            cur.execute("DELETE FROM users")
        conn.commit()


@pytest.fixture
def app(clean_db):
    test_user_service = UserService(database_url=clean_db)
    test_goal_service = GoalService(database_url=clean_db)
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
    from app.routers import goals as goals_router_module

    original_user_service = auth_router_module.user_service
    original_goal_service = goals_router_module.goal_service
    original_session_service = goals_router_module.session_service
    auth_router_module.user_service = test_user_service
    goals_router_module.goal_service = test_goal_service
    goals_router_module.session_service = test_session_service

    app.include_router(auth_router, prefix="/api/auth", tags=["Auth"])
    app.include_router(goals_router, prefix="/api", tags=["Goals"])

    yield app

    auth_router_module.user_service = original_user_service
    goals_router_module.goal_service = original_goal_service
    goals_router_module.session_service = original_session_service


@pytest.fixture
def client(app):
    return TestClient(app)


@pytest.fixture
def auth_header(client):
    register_response = client.post(
        "/api/auth/register",
        json={
            "email": "goals@example.com",
            "password": "password123",
            "full_name": "Goals User",
        },
    )
    token = register_response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def session_service(clean_db):
    return SessionService(database_url=clean_db)


def test_create_and_list_goals(client, auth_header):
    create_response = client.post(
        "/api/goals",
        headers=auth_header,
        json={
            "title": "Improve executive presence",
            "description": "Practice concise updates in leadership meetings",
            "status": "active",
            "progress": 0.0,
            "milestones": [
                {
                    "id": "milestone-1",
                    "title": "Prepare next staff update",
                    "is_completed": False,
                    "completed_at": None,
                }
            ],
            "related_session_ids": ["session-123"],
        },
    )
    assert create_response.status_code == 200
    created = create_response.json()
    assert created["title"] == "Improve executive presence"
    assert created["user_id"]
    assert len(created["milestones"]) == 1

    list_response = client.get("/api/goals", headers=auth_header)
    assert list_response.status_code == 200
    goals = list_response.json()
    assert len(goals) == 1
    assert goals[0]["id"] == created["id"]


def test_update_goal_recalculates_progress(client, auth_header):
    create_response = client.post(
        "/api/goals",
        headers=auth_header,
        json={
            "title": "Build team rituals",
            "description": "",
            "status": "active",
            "progress": 0.0,
            "milestones": [
                {
                    "id": "milestone-1",
                    "title": "Run retrospective",
                    "is_completed": True,
                    "completed_at": "2026-03-08T12:00:00+00:00",
                },
                {
                    "id": "milestone-2",
                    "title": "Launch weekly standup",
                    "is_completed": False,
                    "completed_at": None,
                },
            ],
            "related_session_ids": [],
        },
    )
    goal_id = create_response.json()["id"]

    update_response = client.put(
        f"/api/goals/{goal_id}",
        headers=auth_header,
        json={
            "title": "Build team rituals",
            "description": "Keep the team aligned and accountable",
            "status": "active",
            "progress": 0.0,
            "milestones": [
                {
                    "id": "milestone-1",
                    "title": "Run retrospective",
                    "is_completed": True,
                    "completed_at": "2026-03-08T12:00:00+00:00",
                },
                {
                    "id": "milestone-2",
                    "title": "Launch weekly standup",
                    "is_completed": True,
                    "completed_at": "2026-03-09T12:00:00+00:00",
                },
            ],
            "related_session_ids": ["session-1"],
        },
    )
    assert update_response.status_code == 200
    updated = update_response.json()
    assert updated["progress"] == 1.0
    assert updated["related_session_ids"] == ["session-1"]


def test_delete_goal(client, auth_header):
    create_response = client.post(
        "/api/goals",
        headers=auth_header,
        json={
            "title": "Prepare promotion packet",
            "description": "",
            "status": "active",
            "progress": 0.0,
            "milestones": [],
            "related_session_ids": [],
        },
    )
    goal_id = create_response.json()["id"]

    delete_response = client.delete(f"/api/goals/{goal_id}", headers=auth_header)
    assert delete_response.status_code == 204

    fetch_response = client.get(f"/api/goals/{goal_id}", headers=auth_header)
    assert fetch_response.status_code == 404


def test_related_sessions_sync_back_to_session_goal_ids(client, auth_header, session_service):
    user_me = client.get("/api/auth/me", headers=auth_header)
    user_id = user_me.json()["id"]
    session = session_service.create_session(
        user_id=user_id,
        persona="direct_challenger",
        session_type="goal_review",
        input_mode="text",
    )

    create_response = client.post(
        "/api/goals",
        headers=auth_header,
        json={
            "title": "Improve stakeholder updates",
            "description": "",
            "status": "active",
            "progress": 0.0,
            "milestones": [],
            "related_session_ids": [session["id"]],
        },
    )
    assert create_response.status_code == 200
    goal_id = create_response.json()["id"]

    linked_session = session_service.get_session(session["id"], user_id)
    assert linked_session["goal_ids"] == [goal_id]

    update_response = client.put(
        f"/api/goals/{goal_id}",
        headers=auth_header,
        json={
            "title": "Improve stakeholder updates",
            "description": "Focus on concise weekly progress updates",
            "status": "active",
            "progress": 0.0,
            "milestones": [],
            "related_session_ids": [],
        },
    )
    assert update_response.status_code == 200

    unlinked_session = session_service.get_session(session["id"], user_id)
    assert unlinked_session["goal_ids"] == []
