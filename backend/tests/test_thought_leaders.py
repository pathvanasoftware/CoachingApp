import pytest
from app.prompts.thought_leaders import (
    get_framework_for_context,
    RADICAL_CANDOR,
    MAKING_OF_A_MANAGER,
    TAKE_BACK_YOUR_POWER,
    DARE_TO_LEAD,
    WHAT_GOT_YOU_HERE,
)


def test_radical_candor_triggered_by_feedback():
    """Test that feedback conversations trigger Radical Candor"""
    msg = "I need to give my team member some difficult feedback about their performance"
    framework = get_framework_for_context(msg, "neutral", "professional_growth")
    assert "Radical Candor" in framework
    assert "Care Personally + Challenge Directly" in framework


def test_making_of_manager_for_new_managers():
    """Test that new manager scenarios trigger Julie Zhuo's framework"""
    msg = "I just became a first time manager and I'm not sure how to delegate"
    framework = get_framework_for_context(msg, "uncertain", "leadership_effectiveness")
    assert "Making of a Manager" in framework
    assert "Julie Zhuo" in framework
    assert "delegation" in framework.lower()


def test_take_back_power_for_imposter_syndrome():
    """Test that imposter syndrome triggers Deborah Liu's framework"""
    msg = "I feel like an imposter in this role, I don't think I deserve this promotion"
    framework = get_framework_for_context(msg, "self_doubt", "career_advancement")
    assert "Take Back Your Power" in framework
    assert "Deborah Liu" in framework
    assert "imposter" in framework.lower()


def test_take_back_power_for_negotiation():
    """Test that salary negotiation triggers Deborah Liu's framework"""
    msg = "I want to negotiate a raise but I'm not sure if I should ask"
    framework = get_framework_for_context(msg, "uncertain", "career_advancement")
    assert "Take Back Your Power" in framework
    assert "negotiation" in framework.lower() or "Negotiation" in framework


def test_dare_to_lead_for_vulnerability():
    """Test that vulnerability topics trigger Brené Brown's framework"""
    msg = "I want to be more authentic with my team but I'm afraid of being vulnerable"
    framework = get_framework_for_context(msg, "anxious", "leadership_effectiveness")
    assert "Dare to Lead" in framework
    assert "Brené Brown" in framework or "Brene Brown" in framework
    assert "vulnerability" in framework.lower() or "Vulnerability" in framework


def test_what_got_you_here_for_senior_exec():
    """Test that senior executive issues trigger Marshall Goldsmith's framework"""
    msg = "I'm a VP and got some 360 feedback that I need to work on, people say I add too much value"
    framework = get_framework_for_context(msg, "reflective", "leadership_effectiveness")
    assert "What Got You Here" in framework
    assert "Marshall Goldsmith" in framework
    assert "adding too much value" in framework.lower() or "Adding too much value" in framework


def test_default_fallback_to_radical_candor():
    """Test that generic messages default to Radical Candor (most universal)"""
    msg = "I need help with my career"
    framework = get_framework_for_context(msg, "neutral", "professional_growth")
    # Should get Radical Candor as default
    assert "Radical Candor" in framework or "Kim Scott" in framework


def test_leadership_goal_triggers_making_of_manager():
    """Test that leadership_effectiveness goal triggers Making of a Manager"""
    msg = "I'm struggling with my team"
    framework = get_framework_for_context(msg, "frustrated", "leadership_effectiveness")
    assert "Making of a Manager" in framework


def test_career_advancement_goal_triggers_take_back_power():
    """Test that career_advancement goal triggers Take Back Your Power"""
    msg = "I want to advance in my career"
    framework = get_framework_for_context(msg, "ambitious", "career_advancement")
    assert "Take Back Your Power" in framework


def test_frameworks_contain_actionable_content():
    """Test that all frameworks have actionable guidance"""
    frameworks = [
        RADICAL_CANDOR,
        MAKING_OF_A_MANAGER,
        TAKE_BACK_YOUR_POWER,
        DARE_TO_LEAD,
        WHAT_GOT_YOU_HERE,
    ]
    
    for framework in frameworks:
        # Should have "When to use" section
        assert "When to use:" in framework
        # Should have key phrases or questions
        assert ("Key questions:" in framework or "Key phrases:" in framework or "Key Frameworks:" in framework)
        # Should have application guidance
        assert "Application in coaching:" in framework


def test_frameworks_are_comprehensive():
    """Test that frameworks provide sufficient detail"""
    frameworks = [
        RADICAL_CANDOR,
        MAKING_OF_A_MANAGER,
        TAKE_BACK_YOUR_POWER,
        DARE_TO_LEAD,
        WHAT_GOT_YOU_HERE,
    ]
    
    for framework in frameworks:
        # Should be substantial (at least 500 chars)
        assert len(framework) > 500
        # Should have multiple sections
        assert framework.count("**") >= 4
