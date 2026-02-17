from fastapi.testclient import TestClient

from main import app
from app.routers import chat as chat_router
from app.services.llm import CoachingResponse


def test_health_and_root():
    client = TestClient(app)
    r = client.get("/")
    assert r.status_code == 200
    assert r.json().get("status") == "ok"


def test_debug_profile_endpoint(tmp_path, monkeypatch):
    from app.services import memory_store
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))

    client = TestClient(app)
    r = client.get("/api/debug/profile/test-user")
    assert r.status_code == 200
    body = r.json()
    assert body["user_id"] == "test-user"
    assert "profile" in body


def test_quick_replies_endpoint():
    client = TestClient(app)
    r = client.post("/api/chat/quick-replies", params={"message": "I want a promotion", "response": "Let's define options"})
    assert r.status_code == 200
    assert len(r.json()["quick_replies"]) == 4


def test_chat_stream_endpoint(monkeypatch):
    async def _fake(_req):
        return CoachingResponse(
            response="One two three",
            quick_replies=["a", "b", "c", "d"],
            style_used="strategic",
            emotion_detected="neutral",
            goal_link="career_advancement",
        )

    monkeypatch.setattr(chat_router, "get_coaching_response", _fake)

    client = TestClient(app)
    r = client.post(
        "/api/v1/chat-stream",
        json={"sessionId": "s1", "message": "hello", "persona": "direct", "coachingStyle": "strategic", "userId": "u1"},
    )
    assert r.status_code == 200
    body = r.text
    assert '"meta"' in body
    assert "[DONE]" in body
