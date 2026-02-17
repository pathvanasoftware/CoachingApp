import json
from datetime import datetime

from app.services import emotion_engine, style_router, context_engine, behavior_tracker, llm


def test_style_router_prefers_explicit_style():
    assert style_router.route_style("help me", preferred_style="strategic") == "strategic"


def test_style_router_heuristics():
    assert style_router.route_style("urgent decision now") == "directive"
    assert style_router.route_style("I'm not sure what options I have") == "facilitative"
    assert style_router.route_style("I feel anxious and overwhelmed") == "supportive"
    assert style_router.route_style("Need long term strategy for org design") == "strategic"


def test_emotion_engine_outputs_scores():
    result = emotion_engine.analyze_text_emotion("I'm overwhelmed and anxious about this deadline")
    assert result.primary in emotion_engine.EMOTION_LABELS
    assert "high_stress" in result.scores
    assert 0 <= result.sentiment["negative"] <= 1
    assert 0 <= result.linguistic_markers["engagement"] <= 1


def test_context_triggers_infer_deadline():
    trig = emotion_engine.infer_context_triggers("Deadline is tomorrow EOD", now=datetime(2026, 1, 1, 9, 0, 0))
    assert trig["situational_trigger"] == "deadline_pressure"
    assert trig["time_of_day"] == "9"


def test_context_packet_and_goal_link():
    packet = context_engine.build_context_packet(
        "I want a promotion",
        [{"role": "user", "content": "hello"}, {"role": "assistant", "content": "hi"}],
        "Q1 planning",
    )
    assert "Explicit context" in packet
    assert context_engine.infer_goal_link("I want promotion to VP") == "career_advancement"


def test_behavior_tracker_updates_and_shift():
    profile = {}
    profile = behavior_tracker.update_behavior_signals(profile, style_used="strategic", goal_link="career_advancement")
    profile = behavior_tracker.update_behavior_signals(profile, style_used="strategic", goal_link="career_advancement")
    assert profile["style_usage"]["strategic"] == 2
    assert behavior_tracker.style_preference_shift(profile).startswith("stable") or behavior_tracker.style_preference_shift(profile).startswith("leaning")


def test_llm_helpers():
    assert llm.detect_crisis("I want to kill myself") is True
    assert llm.detect_crisis("I need help with promotion") is False

    replies = llm.generate_quick_replies("I need a promotion", "Let's define your goal", None)
    assert len(replies) == 4
    assert all(isinstance(x, str) and x for x in replies)

    parsed = llm._safe_parse_structured_output('{"response":"ok","quick_replies":["a","b","c","d"]}')
    assert isinstance(parsed, dict)
    assert parsed["response"] == "ok"


def test_safe_parse_extracts_embedded_json():
    raw = "prefix\n{\"response\":\"ok\",\"quick_replies\":[\"a\",\"b\",\"c\",\"d\"]}\nsuffix"
    parsed = llm._safe_parse_structured_output(raw)
    assert parsed["response"] == "ok"
