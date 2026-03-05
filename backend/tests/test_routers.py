import asyncio

from fastapi.testclient import TestClient

from main import app
from app.routers import chat as chat_router
from app.services.llm import CoachingResponse
from app.services.cache import InMemoryCache


def test_health_and_root():
    client = TestClient(app)
    r = client.get("/")
    assert r.status_code == 200
    assert r.json().get("status") == "ok"

    h = client.get("/health")
    assert h.status_code == 200
    body = h.json()
    assert body.get("status") == "ok"
    assert "git_sha" in body
    assert "git_sha_short" in body
    assert "deployed_at" in body


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
    monkeypatch.setenv("ANTHROPIC_API_KEY", "sk-ant-fake-key-for-testing")

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


def test_chat_returns_202_when_follower_wait_times_out(monkeypatch):
    monkeypatch.setattr(chat_router, "_anthropic_available", lambda: True)
    monkeypatch.setattr(chat_router, "_openai_available", lambda: False)
    monkeypatch.setattr(chat_router, "response_cache", InMemoryCache())
    monkeypatch.setattr(chat_router, "FOLLOWER_WAIT_SECONDS_CHAT", 0.01)

    async def _always_locked(*_args, **_kwargs):
        return False

    monkeypatch.setattr(chat_router.response_cache, "acquire_lock", _always_locked)

    client = TestClient(app)
    r = client.post(
        "/api/chat/",
        json={"message": "hello", "user_id": "u-timeout", "request_id": "req-timeout-1"},
    )

    assert r.status_code == 202
    body = r.json()
    assert body["status"] == "processing"
    assert body["request_id"] == "req-timeout-1"
    assert "retry_after_ms" in body


def test_chat_stream_uses_cached_response_without_llm(monkeypatch):
    monkeypatch.setattr(chat_router, "_anthropic_available", lambda: True)
    monkeypatch.setattr(chat_router, "_openai_available", lambda: False)

    cache = InMemoryCache()
    monkeypatch.setattr(chat_router, "response_cache", cache)

    request_body = {
        "sessionId": "s-cache-1",
        "message": "hello cached",
        "persona": "direct",
        "coachingStyle": "strategic",
        "userId": "u-cache-1",
        "requestId": "req-cache-1",
    }
    signature = chat_router._stream_signature(chat_router.ChatStreamRequest(**request_body))
    record = {
        "request_id": "req-cache-1",
        "signature": signature,
        "response": {
            "response": "cached one two",
            "quick_replies": ["a", "b", "c", "d"],
            "style_used": "strategic",
            "emotion_detected": "neutral",
            "goal_link": "career_advancement",
        },
    }
    asyncio.run(cache.set_json("idem:u-cache-1:req-cache-1", record, 60))

    async def _should_not_run(_req):
        raise AssertionError("LLM should not run on cache hit")

    monkeypatch.setattr(chat_router, "get_coaching_response", _should_not_run)

    client = TestClient(app)
    r = client.post("/api/v1/chat-stream", json=request_body)

    assert r.status_code == 200
    body = r.text
    assert '"meta"' in body
    assert "cached" in body
    assert "[DONE]" in body
