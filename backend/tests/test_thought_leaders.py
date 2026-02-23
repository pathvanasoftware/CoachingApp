import pytest
from app.prompts.proprietary_frameworks import (
    get_framework_for_context,
    DIRECT_CARE_FEEDBACK,
    LEADERSHIP_FOUNDATION,
    POWER_OWNERSHIP_MODEL,
    COURAGEOUS_LEADERSHIP,
    EXECUTIVE_EVOLUTION,
)


def test_direct_care_triggered_by_feedback():
    """Test that feedback conversations trigger Direct Care Feedback"""
    msg = "I need to give my team member some difficult feedback about their performance"
    framework = get_framework_for_context(msg, "neutral", "professional_growth")
    assert "Direct Care Feedback" in framework
    assert "empathy" in framework.lower() and "clarity" in framework.lower()


def test_leadership_foundation_for_new_managers():
    """Test that new manager scenarios trigger Leadership Foundation"""
    msg = "I just became a first time manager and I'm not sure how to delegate"
    framework = get_framework_for_context(msg, "uncertain", "leadership_effectiveness")
    assert "Leadership Foundation" in framework
    assert "delegation" in framework.lower()


def test_power_ownership_for_imposter_syndrome():
    """Test that imposter syndrome triggers Power Ownership Model"""
    msg = "I feel like an imposter in this role, I don't think I deserve this promotion"
    framework = get_framework_for_context(msg, "self_doubt", "career_advancement")
    assert "Power Ownership Model" in framework
    assert "limiting belief" in framework.lower() or "not ready" in framework.lower()


def test_power_ownership_for_negotiation():
    """Test that salary negotiation triggers Power Ownership Model"""
    msg = "I want to negotiate a raise but I'm not sure if I should ask"
    framework = get_framework_for_context(msg, "uncertain", "career_advancement")
    assert "Power Ownership Model" in framework
    assert "negotiation" in framework.lower() or "Negotiation" in framework


def test_courageous_leadership_for_vulnerability():
    """Test that vulnerability topics trigger Courageous Leadership"""
    msg = "I want to be more authentic with my team but I'm afraid of being vulnerable"
    framework = get_framework_for_context(msg, "anxious", "leadership_effectiveness")
    assert "Courageous Leadership" in framework
    assert "vulnerability" in framework.lower() or "courage" in framework.lower()


def test_executive_evolution_for_senior_exec():
    """Test that senior executive issues trigger Executive Evolution"""
    msg = "I'm a VP and got some 360 feedback that I need to work on"
    framework = get_framework_for_context(msg, "reflective", "leadership_effectiveness")
    assert "Executive Evolution" in framework
    assert "derailer" in framework.lower() or "executive" in framework.lower()


def test_default_fallback_to_direct_care():
    """Test that generic messages default to Direct Care Feedback (most universal)"""
    msg = "I need help with my career"
    framework = get_framework_for_context(msg, "neutral", "professional_growth")
    # Should get Direct Care Feedback as default
    assert "Direct Care Feedback" in framework


def test_leadership_goal_triggers_leadership_foundation():
    """Test that leadership_effectiveness goal triggers Leadership Foundation"""
    msg = "I'm struggling with my team"
    framework = get_framework_for_context(msg, "frustrated", "leadership_effectiveness")
    assert "Leadership Foundation" in framework


def test_career_advancement_goal_triggers_power_ownership():
    """Test that career_advancement goal triggers Power Ownership Model"""
    msg = "I want to advance in my career"
    framework = get_framework_for_context(msg, "ambitious", "career_advancement")
    assert "Power Ownership Model" in framework


def test_frameworks_contain_actionable_content():
    """Test that all frameworks have actionable guidance"""
    frameworks = [
        DIRECT_CARE_FEEDBACK,
        LEADERSHIP_FOUNDATION,
        POWER_OWNERSHIP_MODEL,
        COURAGEOUS_LEADERSHIP,
        EXECUTIVE_EVOLUTION,
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
        DIRECT_CARE_FEEDBACK,
        LEADERSHIP_FOUNDATION,
        POWER_OWNERSHIP_MODEL,
        COURAGEOUS_LEADERSHIP,
        EXECUTIVE_EVOLUTION,
    ]
    
    for framework in frameworks:
        # Should be substantial (at least 500 chars)
        assert len(framework) > 500
        # Should have multiple sections
        assert framework.count("**") >= 4


def test_frameworks_are_proprietary():
    """Test that frameworks use proprietary names, not third-party names"""
    frameworks = [
        DIRECT_CARE_FEEDBACK,
        LEADERSHIP_FOUNDATION,
        POWER_OWNERSHIP_MODEL,
        COURAGEOUS_LEADERSHIP,
        EXECUTIVE_EVOLUTION,
    ]
    
    for framework in frameworks:
        # Should NOT contain third-party author names
        assert "Kim Scott" not in framework
        assert "Julie Zhuo" not in framework
        assert "Deborah Liu" not in framework
        assert "Brené Brown" not in framework
        assert "Marshall Goldsmith" not in framework
        
        # Should contain ™ symbol (trademark)
        assert "™" in framework
