import asyncio
from types import SimpleNamespace

from app.services import llm


class _FakeCompletions:
    def __init__(self, payload: str, should_raise: bool = False):
        self.payload = payload
        self.should_raise = should_raise

    async def create(self, **kwargs):
        if self.should_raise:
            raise RuntimeError("boom")
        msg = SimpleNamespace(content=self.payload)
        choice = SimpleNamespace(message=msg)
        return SimpleNamespace(choices=[choice])


class _FakeClient:
    def __init__(self, payload: str, should_raise: bool = False):
        self.chat = SimpleNamespace(completions=_FakeCompletions(payload, should_raise))


def test_get_coaching_response_crisis_branch(tmp_path, monkeypatch):
    from app.services import memory_store
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))

    req = llm.CoachingRequest(message="I want to kill myself", user_id="u1")
    resp = asyncio.run(llm.get_coaching_response(req))

    assert "988" in resp.response
    assert resp.goal_link == "wellbeing_first"
    assert resp.emotion_primary == "high_stress"


def test_get_coaching_response_structured_success(tmp_path, monkeypatch):
    from app.services import memory_store
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))

    payload = '{"response":"Plan this in 3 steps.","quick_replies":["Step 1","Step 2","Step 3","Step 4"],"suggested_actions":["a1"]}'
    monkeypatch.setattr(llm, "get_openai_client", lambda: _FakeClient(payload))

    req = llm.CoachingRequest(message="I need promotion strategy", user_id="u2", coaching_style="strategic")
    resp = asyncio.run(llm.get_coaching_response(req))

    assert resp.response.startswith("Plan this")
    assert len(resp.quick_replies) == 4
    assert resp.style_used in ["strategic", "supportive", "directive", "facilitative"]
    assert resp.emotion_scores is not None


def test_get_coaching_response_fallback_on_bad_json(tmp_path, monkeypatch):
    from app.services import memory_store
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))

    monkeypatch.setattr(llm, "get_openai_client", lambda: _FakeClient("not-json response"))
    req = llm.CoachingRequest(message="help me with team conflict", user_id="u3")
    resp = asyncio.run(llm.get_coaching_response(req))

    assert isinstance(resp.response, str)
    assert len(resp.quick_replies) == 4
    assert resp.goal_link is not None


def test_get_coaching_response_exception_fallback(tmp_path, monkeypatch):
    from app.services import memory_store
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))

    monkeypatch.setattr(llm, "get_openai_client", lambda: _FakeClient("", should_raise=True))
    req = llm.CoachingRequest(message="I'm uncertain", user_id="u4")
    resp = asyncio.run(llm.get_coaching_response(req))

    assert "I'm here to help" in resp.response
    assert len(resp.quick_replies) == 4
