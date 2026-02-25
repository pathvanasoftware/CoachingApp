"""
Test enhanced proprietary frameworks with new modules from 10 classic coaching books.

Tests verify:
1. Framework selection triggers correctly
2. Enhanced modules are present and well-formed
3. New concepts are integrated properly
4. Framework content quality
"""

import pytest
from app.prompts.proprietary_frameworks import (
    get_framework_for_context,
    DIRECT_CARE_FEEDBACK,
    LEADERSHIP_FOUNDATION,
    POWER_OWNERSHIP_MODEL,
    COURAGEOUS_LEADERSHIP,
    EXECUTIVE_EVOLUTION,
)


class TestEnhancedDirectCareFeedback:
    """Test Direct Care Feedback™ enhanced modules"""
    
    def test_conversation_safety_module_present(self):
        """Verify Conversation Safety module is integrated"""
        assert "Conversation Safety" in DIRECT_CARE_FEEDBACK
        assert "psychological safety" in DIRECT_CARE_FEEDBACK.lower()
        assert "shared purpose" in DIRECT_CARE_FEEDBACK.lower()
    
    def test_fact_vs_story_module_present(self):
        """Verify Fact vs Story module is integrated"""
        assert "Fact vs Story" in DIRECT_CARE_FEEDBACK
        assert "Facts:" in DIRECT_CARE_FEEDBACK
        assert "Stories:" in DIRECT_CARE_FEEDBACK
        assert "story i'm telling myself" in DIRECT_CARE_FEEDBACK.lower()
    
    def test_feedback_reception_module_present(self):
        """Verify Feedback Reception module is integrated"""
        assert "Feedback Reception" in DIRECT_CARE_FEEDBACK
        assert "three feedback types" in DIRECT_CARE_FEEDBACK.lower()
        assert "triggers" in DIRECT_CARE_FEEDBACK.lower()
    
    def test_enhanced_modules_actionable(self):
        """Verify enhanced modules have actionable guidance"""
        # Should have specific techniques
        assert "rebuild" in DIRECT_CARE_FEEDBACK.lower() or "pause" in DIRECT_CARE_FEEDBACK.lower()
        # Should mention application
        assert "application" in DIRECT_CARE_FEEDBACK.lower() or "practice" in DIRECT_CARE_FEEDBACK.lower()


class TestEnhancedLeadershipFoundation:
    """Test Leadership Foundation™ enhanced modules"""
    
    def test_coaching_one_on_one_module_present(self):
        """Verify Coaching-Based 1-on-1 module is integrated"""
        assert "1-on-1" in LEADERSHIP_FOUNDATION or "one-on-one" in LEADERSHIP_FOUNDATION.lower()
        assert "2 min" in LEADERSHIP_FOUNDATION or "2-5-3" in LEADERSHIP_FOUNDATION
        assert "agenda" in LEADERSHIP_FOUNDATION.lower()
    
    def test_motivation_design_module_present(self):
        """Verify Motivation Design (AMP) module is integrated"""
        assert "Motivation Design" in LEADERSHIP_FOUNDATION or "motivation" in LEADERSHIP_FOUNDATION.lower()
        assert "Autonomy" in LEADERSHIP_FOUNDATION
        assert "Mastery" in LEADERSHIP_FOUNDATION
        assert "Purpose" in LEADERSHIP_FOUNDATION
        assert "intrinsic motivation" in LEADERSHIP_FOUNDATION.lower()
    
    def test_purpose_driven_leadership_module_present(self):
        """Verify Purpose-Driven Leadership module is integrated"""
        assert "Purpose-Driven" in LEADERSHIP_FOUNDATION or "purpose-driven" in LEADERSHIP_FOUNDATION.lower()
        assert "WHY" in LEADERSHIP_FOUNDATION
        assert "HOW" in LEADERSHIP_FOUNDATION
        assert "WHAT" in LEADERSHIP_FOUNDATION
        assert "inside-out" in LEADERSHIP_FOUNDATION.lower()
    
    def test_has_powerful_questions(self):
        """Verify framework includes coaching questions"""
        questions = [
            "real challenge",
            "have you tried",
            "what do you need",
        ]
        found_questions = sum(1 for q in questions if q in LEADERSHIP_FOUNDATION.lower())
        assert found_questions >= 2, "Should have at least 2 powerful questions"


class TestEnhancedPowerOwnershipModel:
    """Test Power Ownership Model™ enhanced modules"""
    
    def test_inner_dialogue_module_present(self):
        """Verify Inner Dialogue Management module is integrated"""
        assert "Inner Dialogue" in POWER_OWNERSHIP_MODEL or "inner dialogue" in POWER_OWNERSHIP_MODEL.lower()
        assert "Inner Critic" in POWER_OWNERSHIP_MODEL
        assert "Natural Ability" in POWER_OWNERSHIP_MODEL
        assert "interference" in POWER_OWNERSHIP_MODEL.lower()
    
    def test_growth_mindset_module_present(self):
        """Verify Growth Mindset Development module is integrated"""
        assert "Growth Mindset" in POWER_OWNERSHIP_MODEL or "growth mindset" in POWER_OWNERSHIP_MODEL.lower()
        assert "Fixed mindset" in POWER_OWNERSHIP_MODEL or "fixed mindset" in POWER_OWNERSHIP_MODEL.lower()
        assert "haven't mastered" in POWER_OWNERSHIP_MODEL.lower() or "not yet" in POWER_OWNERSHIP_MODEL.lower()
        assert "embrace challenge" in POWER_OWNERSHIP_MODEL.lower()
    
    def test_intrinsic_motivation_module_present(self):
        """Verify Intrinsic Motivation Activation module is integrated"""
        assert "Intrinsic Motivation" in POWER_OWNERSHIP_MODEL or "intrinsic motivation" in POWER_OWNERSHIP_MODEL.lower()
        assert "energizes" in POWER_OWNERSHIP_MODEL.lower() or "energy" in POWER_OWNERSHIP_MODEL.lower()
        assert "autonomy" in POWER_OWNERSHIP_MODEL.lower() or "mastery" in POWER_OWNERSHIP_MODEL.lower()
    
    def test_addresses_limiting_beliefs(self):
        """Verify framework addresses limiting beliefs"""
        assert "limiting belief" in POWER_OWNERSHIP_MODEL.lower()
        # Should provide reframing
        assert "reframe" in POWER_OWNERSHIP_MODEL.lower() or "not yet" in POWER_OWNERSHIP_MODEL.lower()


class TestEnhancedCourageousLeadership:
    """Test Courageous Leadership™ enhanced modules"""
    
    def test_emotional_intelligence_module_present(self):
        """Verify Emotional Intelligence Development module is integrated"""
        assert "Emotional Intelligence" in COURAGEOUS_LEADERSHIP or "emotional intelligence" in COURAGEOUS_LEADERSHIP.lower()
        assert "Self-Awareness" in COURAGEOUS_LEADERSHIP
        assert "Self-Management" in COURAGEOUS_LEADERSHIP
        assert "Empathy" in COURAGEOUS_LEADERSHIP
        assert "Social Skills" in COURAGEOUS_LEADERSHIP
    
    def test_emotional_contagion_module_present(self):
        """Verify Emotional Contagion Awareness module is integrated"""
        assert "Emotional Contagion" in COURAGEOUS_LEADERSHIP or "contagion" in COURAGEOUS_LEADERSHIP.lower()
        assert "spread" in COURAGEOUS_LEADERSHIP.lower() or "influence" in COURAGEOUS_LEADERSHIP.lower()
        assert "leader" in COURAGEOUS_LEADERSHIP.lower()
    
    def test_empathy_practice_module_present(self):
        """Verify Empathy in Practice module is integrated"""
        assert "Empathy" in COURAGEOUS_LEADERSHIP
        # Should have types of empathy
        empathy_types = ["cognitive", "emotional", "compassionate"]
        found_types = sum(1 for t in empathy_types if t in COURAGEOUS_LEADERSHIP.lower())
        assert found_types >= 2, "Should have at least 2 types of empathy"
    
    def test_has_emotional_management_tools(self):
        """Verify framework has emotional management tools"""
        assert "manage" in COURAGEOUS_LEADERSHIP.lower() or "control" in COURAGEOUS_LEADERSHIP.lower()
        assert "aware" in COURAGEOUS_LEADERSHIP.lower() or "awareness" in COURAGEOUS_LEADERSHIP.lower()


class TestEnhancedExecutiveEvolution:
    """Test Executive Evolution™ enhanced modules"""
    
    def test_executive_coaching_principles_module_present(self):
        """Verify Executive Coaching Principles module is integrated"""
        assert "Executive Coaching" in EXECUTIVE_EVOLUTION or "executive coaching" in EXECUTIVE_EVOLUTION.lower()
        assert "People First" in EXECUTIVE_EVOLUTION or "people first" in EXECUTIVE_EVOLUTION.lower()
        assert "Challenge Assumptions" in EXECUTIVE_EVOLUTION or "challenge" in EXECUTIVE_EVOLUTION.lower()
        assert "Independence" in EXECUTIVE_EVOLUTION or "independent" in EXECUTIVE_EVOLUTION.lower()
    
    def test_team_dynamics_module_present(self):
        """Verify Team Dynamics Observation module is integrated"""
        assert "Team Dynamics" in EXECUTIVE_EVOLUTION or "team dynamics" in EXECUTIVE_EVOLUTION.lower()
        assert "communication pattern" in EXECUTIVE_EVOLUTION.lower() or "decision-making" in EXECUTIVE_EVOLUTION.lower()
        assert "observe" in EXECUTIVE_EVOLUTION.lower() or "observation" in EXECUTIVE_EVOLUTION.lower()
    
    def test_blind_spot_module_present(self):
        """Verify Blind Spot Identification module is integrated"""
        assert "Blind Spot" in EXECUTIVE_EVOLUTION or "blind spot" in EXECUTIVE_EVOLUTION.lower()
        assert "360" in EXECUTIVE_EVOLUTION
        assert "feedback" in EXECUTIVE_EVOLUTION.lower()
        assert "stakeholder" in EXECUTIVE_EVOLUTION.lower()
    
    def test_addresses_executive_derailers(self):
        """Verify framework addresses executive derailers"""
        # Should mention derailers or limiting behaviors
        assert "derailer" in EXECUTIVE_EVOLUTION.lower() or "limit" in EXECUTIVE_EVOLUTION.lower()
        # Should have systematic approach
        assert "systematic" in EXECUTIVE_EVOLUTION.lower() or "quarterly" in EXECUTIVE_EVOLUTION.lower()


class TestFrameworkIntegration:
    """Test that enhanced modules are well-integrated"""
    
    def test_all_frameworks_have_enhanced_section(self):
        """Verify all frameworks have 'Enhanced Concepts' section"""
        frameworks = [
            DIRECT_CARE_FEEDBACK,
            LEADERSHIP_FOUNDATION,
            POWER_OWNERSHIP_MODEL,
            COURAGEOUS_LEADERSHIP,
            EXECUTIVE_EVOLUTION,
        ]
        
        for framework in frameworks:
            assert "Enhanced Concepts" in framework, f"Framework should have Enhanced Concepts section"
            assert "---" in framework, "Enhanced section should be separated"
    
    def test_enhanced_modules_not_just_copies(self):
        """Verify enhanced modules are original expressions, not direct copies"""
        # Should not have direct book quotes or exact phrases
        forbidden_phrases = [
            "co-active coaching",  # trademark
            "inner game",  # trademark
            "golden circle",  # trademark
            "in this book",  # indicates copying
            "the author says",  # indicates copying
        ]
        
        frameworks = [
            DIRECT_CARE_FEEDBACK,
            LEADERSHIP_FOUNDATION,
            POWER_OWNERSHIP_MODEL,
            COURAGEOUS_LEADERSHIP,
            EXECUTIVE_EVOLUTION,
        ]
        
        for framework in frameworks:
            for phrase in forbidden_phrases:
                assert phrase not in framework.lower(), f"Found potentially copied phrase: {phrase}"
    
    def test_frameworks_actionable_and_practical(self):
        """Verify enhanced modules provide practical, actionable guidance"""
        frameworks = [
            DIRECT_CARE_FEEDBACK,
            LEADERSHIP_FOUNDATION,
            POWER_OWNERSHIP_MODEL,
            COURAGEOUS_LEADERSHIP,
            EXECUTIVE_EVOLUTION,
        ]
        
        for framework in frameworks:
            # Should have practical application indicators
            practical_indicators = [
                "ask",
                "practice",
                "try",
                "use",
                "apply",
                "question",
            ]
            found_indicators = sum(1 for ind in practical_indicators if ind in framework.lower())
            assert found_indicators >= 3, f"Framework should have at least 3 practical indicators"
    
    def test_enhanced_modules_improve_framework_depth(self):
        """Verify enhanced modules add significant depth to frameworks"""
        frameworks = [
            ("Direct Care Feedback", DIRECT_CARE_FEEDBACK),
            ("Leadership Foundation", LEADERSHIP_FOUNDATION),
            ("Power Ownership Model", POWER_OWNERSHIP_MODEL),
            ("Courageous Leadership", COURAGEOUS_LEADERSHIP),
            ("Executive Evolution", EXECUTIVE_EVOLUTION),
        ]
        
        for name, framework in frameworks:
            # Enhanced frameworks should be substantial (> 2000 chars)
            assert len(framework) > 2000, f"{name} should be > 2000 chars after enhancement"
            # Should have multiple sections
            assert framework.count("**") >= 10, f"{name} should have multiple sections"


class TestFrameworkSelectionWithEnhancements:
    """Test that framework selection still works with enhanced content"""
    
    def test_feedback_triggers_direct_care(self):
        """Test feedback context selects Direct Care Feedback"""
        msg = "I need to give feedback to my team member"
        framework = get_framework_for_context(msg, "neutral", "professional_growth")
        assert "Direct Care Feedback" in framework
        # Should also include enhanced modules
        assert "Conversation Safety" in framework or "Fact vs Story" in framework
    
    def test_new_manager_triggers_leadership_foundation(self):
        """Test new manager context selects Leadership Foundation"""
        msg = "I'm a new manager struggling with delegation"
        framework = get_framework_for_context(msg, "uncertain", "leadership_effectiveness")
        assert "Leadership Foundation" in framework
        # Should include enhanced modules
        assert "1-on-1" in framework or "Motivation Design" in framework
    
    def test_self_doubt_triggers_power_ownership(self):
        """Test self-doubt context selects Power Ownership Model"""
        msg = "I feel like an imposter, I don't deserve this promotion"
        framework = get_framework_for_context(msg, "self_doubt", "career_advancement")
        assert "Power Ownership Model" in framework
        # Should include enhanced modules
        assert "Inner Dialogue" in framework or "Growth Mindset" in framework
    
    def test_vulnerability_triggers_courageous_leadership(self):
        """Test vulnerability context selects Courageous Leadership"""
        msg = "I want to be more authentic and vulnerable with my team"
        framework = get_framework_for_context(msg, "anxious", "leadership_effectiveness")
        assert "Courageous Leadership" in framework
        # Should include enhanced modules
        assert "Emotional Intelligence" in framework or "Empathy" in framework
    
    def test_executive_triggers_executive_evolution(self):
        """Test executive context selects Executive Evolution"""
        msg = "I'm a VP and got 360 feedback I need to work on"
        framework = get_framework_for_context(msg, "reflective", "leadership_effectiveness")
        assert "Executive Evolution" in framework
        # Should include enhanced modules
        assert "Team Dynamics" in framework or "Blind Spot" in framework


class TestFrameworkQualityMetrics:
    """Test quality metrics for enhanced frameworks"""
    
    def test_frameworks_have_clear_structure(self):
        """Verify frameworks have clear, well-organized structure"""
        frameworks = [
            DIRECT_CARE_FEEDBACK,
            LEADERSHIP_FOUNDATION,
            POWER_OWNERSHIP_MODEL,
            COURAGEOUS_LEADERSHIP,
            EXECUTIVE_EVOLUTION,
        ]
        
        for framework in frameworks:
            # Should have core sections
            assert "Core principle" in framework or "Core focus" in framework
            assert "When to use:" in framework
            assert "Application in coaching:" in framework
            assert "Enhanced Concepts:" in framework
    
    def test_frameworks_use_coaching_language(self):
        """Verify frameworks use appropriate coaching language"""
        coaching_words = [
            "ask",
            "explore",
            "discover",
            "challenge",
            "support",
            "growth",
            "develop",
        ]
        
        frameworks = [
            DIRECT_CARE_FEEDBACK,
            LEADERSHIP_FOUNDATION,
            POWER_OWNERSHIP_MODEL,
            COURAGEOUS_LEADERSHIP,
            EXECUTIVE_EVOLUTION,
        ]
        
        for framework in frameworks:
            found_words = sum(1 for word in coaching_words if word in framework.lower())
            assert found_words >= 4, "Should use coaching language extensively"
    
    def test_enhanced_modules_add_value(self):
        """Verify enhanced modules add tangible value"""
        # Check that enhanced sections have substantial content
        frameworks = [
            DIRECT_CARE_FEEDBACK,
            LEADERSHIP_FOUNDATION,
            POWER_OWNERSHIP_MODEL,
            COURAGEOUS_LEADERSHIP,
            EXECUTIVE_EVOLUTION,
        ]
        
        for framework in frameworks:
            # Split on Enhanced Concepts
            if "Enhanced Concepts:" in framework:
                parts = framework.split("Enhanced Concepts:")
                enhanced_section = parts[1] if len(parts) > 1 else ""
                # Enhanced section should be substantial
                assert len(enhanced_section) > 500, "Enhanced section should be > 500 chars"
                # Should have multiple sub-sections
                assert enhanced_section.count("**") >= 6, "Enhanced section should have multiple sub-sections"
