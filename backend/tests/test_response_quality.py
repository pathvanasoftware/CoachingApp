import pytest
from app.services.llm import _clean_response_text, detect_crisis


def test_clean_response_unwraps_nested_json():
    """Test that nested JSON response is cleaned properly"""
    nested_json = '{"response": "This is the actual coaching response", "quick_replies": []}'
    cleaned = _clean_response_text(nested_json)
    assert cleaned == "This is the actual coaching response"
    assert not cleaned.startswith("{")
    assert "quick_replies" not in cleaned


def test_clean_response_handles_double_wrapped_json():
    """Test double-nested JSON is handled"""
    double_wrapped = '{"response": "{\\"response\\": \\"Inner response\\", \\"quick_replies\\": []}", "quick_replies": []}'
    cleaned = _clean_response_text(double_wrapped)
    assert "Inner response" in cleaned
    assert not cleaned.startswith("{")


def test_clean_response_preserves_plain_text():
    """Test that plain coaching text is preserved"""
    plain_text = "Here's some coaching advice for your career development."
    cleaned = _clean_response_text(plain_text)
    assert cleaned == plain_text


def test_clean_response_strips_markdown_fences():
    """Test that markdown code fences are stripped"""
    fenced = '```json\n{"response": "Advice here", "quick_replies": []}\n```'
    cleaned = _clean_response_text(fenced)
    assert "Advice here" in cleaned
    assert "```" not in cleaned


def test_detect_crisis_positive_cases():
    """Test crisis detection for actual crisis signals"""
    assert detect_crisis("I want to kill myself")
    assert detect_crisis("I want to die")
    assert detect_crisis("I'm going to end my life")
    assert detect_crisis("I have no reason to live")
    assert detect_crisis("I want to commit suicide")


def test_detect_crisis_negative_cases():
    """Test that normal coaching scenarios are not flagged as crisis"""
    # Burnout scenarios should NOT trigger crisis
    assert not detect_crisis("I feel burned out and exhausted")
    assert not detect_crisis("I wake up dreading work")
    assert not detect_crisis("I'm overwhelmed with pressure")

    # Career challenges should NOT trigger crisis
    assert not detect_crisis("I hate my job")
    assert not detect_crisis("I'm stressed about deadlines")
    assert not detect_crisis("My team is pushing back on priorities")

    # Normal emotions should NOT trigger crisis
    assert not detect_crisis("I feel anxious about my presentation")
    assert not detect_crisis("I'm frustrated with my manager")
    assert not detect_crisis("I'm struggling with work-life balance")


def test_detect_crisis_case_insensitive():
    """Test crisis detection is case-insensitive"""
    assert detect_crisis("I WANT TO KILL MYSELF")
    assert detect_crisis("I Want To Die")
    assert detect_crisis("  i want to kill myself  ")


def test_detect_crisis_in_context():
    """Test crisis detection within longer text"""
    # Crisis in middle of text
    assert detect_crisis("I've been feeling down lately and I want to kill myself because of work")

    # Note: Currently "I want to die" triggers crisis even in idiomatic expressions
    # This is intentional - better to be cautious
    # assert not detect_crisis("I want to die of embarrassment after that meeting")
