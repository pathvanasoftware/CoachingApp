import asyncio

from app.services import llm


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_openai_complete(payload: str, should_raise: bool = False):
    """Return a coroutine function that fakes llm_claude._openai_complete."""
    async def _fake(*args, **kwargs):
        if should_raise:
            raise RuntimeError("boom")
        return payload
    return _fake


def _patch_no_anthropic(monkeypatch):
    """Make _anthropic_available() return False so OpenAI fallback is used."""
    from app.services import llm_claude
    monkeypatch.setattr(llm_claude, "_anthropic_available", lambda: False)
    monkeypatch.setattr(llm_claude, "_openai_available", lambda: True)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_get_coaching_response_crisis_branch(tmp_path, monkeypatch):
    from app.services import memory_store
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))

    req = llm.CoachingRequest(message="I want to kill myself", user_id="u1")
    resp = asyncio.run(llm.get_coaching_response(req))

    assert "988" in resp.response
    assert resp.goal_link == "wellbeing_first"
    assert resp.emotion_primary == "high_stress"


def test_get_coaching_response_structured_success(tmp_path, monkeypatch):
    from app.services import memory_store, llm_claude
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))
    _patch_no_anthropic(monkeypatch)

    payload = '{"response":"Plan this in 3 steps.","quick_replies":["Step 1","Step 2","Step 3","Step 4"],"suggested_actions":["a1"]}'
    monkeypatch.setattr(llm_claude, "_openai_complete", _make_openai_complete(payload))

    req = llm.CoachingRequest(message="I need promotion strategy", user_id="u2", coaching_style="strategic")
    resp = asyncio.run(llm.get_coaching_response(req))

    assert resp.response.startswith("Plan this")
    assert len(resp.quick_replies) == 4
    assert resp.style_used in ["strategic", "supportive", "directive", "facilitative"]
    assert resp.emotion_scores is not None


def test_get_coaching_response_fallback_on_bad_json(tmp_path, monkeypatch):
    from app.services import memory_store, llm_claude
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))
    _patch_no_anthropic(monkeypatch)

    monkeypatch.setattr(llm_claude, "_openai_complete", _make_openai_complete("not-json response"))
    req = llm.CoachingRequest(message="help me with team conflict", user_id="u3")
    resp = asyncio.run(llm.get_coaching_response(req))

    assert isinstance(resp.response, str)
    assert len(resp.quick_replies) == 4
    assert resp.goal_link is not None


def test_get_coaching_response_exception_fallback(tmp_path, monkeypatch):
    from app.services import memory_store, llm_claude
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))
    _patch_no_anthropic(monkeypatch)

    monkeypatch.setattr(llm_claude, "_openai_complete", _make_openai_complete("", should_raise=True))
    req = llm.CoachingRequest(message="I'm uncertain", user_id="u4")
    resp = asyncio.run(llm.get_coaching_response(req))

    assert "I'm here to help" in resp.response
    assert len(resp.quick_replies) == 4
