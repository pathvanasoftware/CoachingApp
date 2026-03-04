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


# ---------------------------------------------------------------------------
# Inquiry-First Behavior Tests
# ---------------------------------------------------------------------------

def test_inquiry_first_broad_input_asks_question(tmp_path, monkeypatch):
    """Broad inputs should result in a clarifying question."""
    from app.services import memory_store, llm_claude
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))
    _patch_no_anthropic(monkeypatch)

    payload = '{"response":"I hear you. What specifically about performance feels off — is it output, quality, or engagement?", "quick_replies":["Output is down","Quality is slipping","Engagement is low","All of the above"]}'
    monkeypatch.setattr(llm_claude, "_openai_complete", _make_openai_complete(payload))

    req = llm.CoachingRequest(message="My team's performance is slipping", user_id="u5")
    resp = asyncio.run(llm.get_coaching_response(req))

    assert "?" in resp.response, "Broad input should result in a clarifying question"


def test_inquiry_first_no_long_framework_early_turn(tmp_path, monkeypatch):
    """Early turns with sparse context should avoid long numbered frameworks."""
    from app.services import memory_store, llm_claude
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))
    _patch_no_anthropic(monkeypatch)

    payload = '{"response":"That sounds frustrating. Before I suggest anything, what would \"back on track\" look like for you in concrete terms?", "quick_replies":["Clear priorities","Better execution","More alignment","All of these"]}'
    monkeypatch.setattr(llm_claude, "_openai_complete", _make_openai_complete(payload))

    req = llm.CoachingRequest(message="I feel stuck and need to get back on track", user_id="u6")
    resp = asyncio.run(llm.get_coaching_response(req))

    assert "1." not in resp.response or "?" in resp.response, \
        "Early turn should ask a question, not present a numbered framework"


def test_inquiry_first_concise_response(tmp_path, monkeypatch):
    """Responses should remain within word limit."""
    from app.services import memory_store, llm_claude
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))
    _patch_no_anthropic(monkeypatch)

    payload = '{"response":"Got it. Let me ask: what is the one outcome that would make this conversation worthwhile for you today?", "quick_replies":["Clear next step","Better understanding","Confidence in plan","Validation of approach"]}'
    monkeypatch.setattr(llm_claude, "_openai_complete", _make_openai_complete(payload))

    req = llm.CoachingRequest(message="Help me think through a career decision", user_id="u7")
    resp = asyncio.run(llm.get_coaching_response(req))

    word_count = len(resp.response.split())
    assert word_count <= 120, f"Response should be <= 120 words, got {word_count}"


def test_inquiry_first_single_question_only(tmp_path, monkeypatch):
    """Response should contain at most one question mark."""
    from app.services import memory_store, llm_claude
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))
    _patch_no_anthropic(monkeypatch)

    payload = '{"response":"I understand. What is the most pressing aspect of this for you right now?", "quick_replies":["Time pressure","Stakeholder expectations","Personal uncertainty","All of them"]}'
    monkeypatch.setattr(llm_claude, "_openai_complete", _make_openai_complete(payload))

    req = llm.CoachingRequest(message="Things feel off and I am not sure what to do", user_id="u8")
    resp = asyncio.run(llm.get_coaching_response(req))

    question_count = resp.response.count("?")
    assert question_count <= 1, f"Response should have at most 1 question, got {question_count}"


def test_inquiry_first_enforced_on_early_sparse_turn(tmp_path, monkeypatch):
    """If model returns advice/no question on early sparse turn, server enforces a clarifying question."""
    from app.services import memory_store, llm_claude
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))
    _patch_no_anthropic(monkeypatch)

    payload = '{"response":"You should run a 3-step framework: align priorities, reset ownership, and track weekly KPIs.", "quick_replies":["Help me start","Too much right now","Need a simpler step","What first?"]}'
    monkeypatch.setattr(llm_claude, "_openai_complete", _make_openai_complete(payload))

    req = llm.CoachingRequest(message="My team is slipping", user_id="u9")
    resp = asyncio.run(llm.get_coaching_response(req))

    assert "?" in resp.response
    assert "framework" not in resp.response.lower()


def test_inquiry_first_not_forced_when_context_rich(tmp_path, monkeypatch):
    """When context is rich, response is not forced into clarifying-question-only mode."""
    from app.services import memory_store, llm_claude
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))
    _patch_no_anthropic(monkeypatch)

    payload = '{"response":"Start with a weekly scorecard for your manager and team, then review misses in Friday retros.", "quick_replies":["Show scorecard template","What to track","How to run retro","How to align manager"]}'
    monkeypatch.setattr(llm_claude, "_openai_complete", _make_openai_complete(payload))

    req = llm.CoachingRequest(
        message="My manager needs weekly quality metrics and my team missed Friday deadlines after the reorg",
        user_id="u10"
    )
    resp = asyncio.run(llm.get_coaching_response(req))

    assert "?" not in resp.response
