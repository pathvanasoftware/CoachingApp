"""
Test coaching dialogue scenarios with enhanced proprietary frameworks.

Validates that frameworks work effectively in realistic coaching conversations.
"""

import pytest
from app.prompts.proprietary_frameworks import get_framework_for_context


class TestFeedbackScenarios:
    """Test Direct Care Feedback™ in realistic feedback conversations"""
    
    def test_performance_feedback_conversation(self):
        """Test framework selection for performance feedback scenario"""
        # Scenario: Manager needs to address underperformance
        user_msg = "One of my team members has been missing deadlines and the quality of their work has dropped. I need to have a difficult conversation with them."
        
        framework = get_framework_for_context(user_msg, "anxious", "professional_growth")
        
        assert "Direct Care Feedback" in framework
        # Should include conversation safety guidance
        assert "safety" in framework.lower()
        # Should include fact vs story technique
        assert "fact" in framework.lower() and "story" in framework.lower()
        # Should have practical phrases
        assert "phrase" in framework.lower() or "example" in framework.lower()
    
    def test_peer_feedback_conversation(self):
        """Test framework for giving feedback to a peer"""
        user_msg = "My colleague keeps interrupting me in meetings and it's affecting my ability to contribute. How should I address this?"
        
        framework = get_framework_for_context(user_msg, "frustrated", "professional_growth")
        
        assert "Direct Care Feedback" in framework
        # Should mention direct communication
        assert "direct" in framework.lower()
        # Should have empathy + clarity balance
        assert "empathy" in framework.lower() and "clarity" in framework.lower()


class TestNewManagerScenarios:
    """Test Leadership Foundation™ in new manager situations"""
    
    def test_delegation_struggle(self):
        """Test framework for new manager struggling with delegation"""
        user_msg = "I just became a manager for the first time and I'm having trouble letting go of tasks. I feel like I need to do everything myself to ensure quality."
        
        framework = get_framework_for_context(user_msg, "overwhelmed", "leadership_effectiveness")
        
        assert "Leadership Foundation" in framework
        # Should include delegation guidance
        assert "delegation" in framework.lower() or "delegate" in framework.lower()
        # Should mention trust or autonomy
        assert "trust" in framework.lower() or "autonomy" in framework.lower()
        # Should have 1-on-1 structure
        assert "1-on-1" in framework or "one-on-one" in framework.lower()
    
    def test_team_motivation_issue(self):
        """Test framework for motivating a disengaged team"""
        user_msg = "My team seems demotivated and disengaged. They do the bare minimum and I'm not sure how to inspire them."
        
        framework = get_framework_for_context(user_msg, "concerned", "leadership_effectiveness")
        
        assert "Leadership Foundation" in framework
        # Should include motivation concepts
        assert "motivation" in framework.lower() or "autonomy" in framework.lower() or "mastery" in framework.lower()
        # Should mention purpose or meaning
        assert "purpose" in framework.lower() or "meaning" in framework.lower()


class TestCareerAdvancementScenarios:
    """Test Power Ownership Model™ in career advancement situations"""
    
    def test_imposter_syndrome(self):
        """Test framework for imposter syndrome before promotion"""
        user_msg = "I just got promoted to Director but I feel like a fraud. I keep thinking they made a mistake and I'm not qualified for this role."
        
        framework = get_framework_for_context(user_msg, "self_doubt", "career_advancement")
        
        assert "Power Ownership Model" in framework
        # Should address self-doubt or limiting beliefs
        assert "limiting" in framework.lower() or "belief" in framework.lower() or "doubt" in framework.lower()
        # Should include growth mindset
        assert "growth" in framework.lower() or "mindset" in framework.lower()
        # Should mention inner dialogue or critic
        assert "inner" in framework.lower() or "critic" in framework.lower()
    
    def test_salary_negotiation(self):
        """Test framework for salary negotiation preparation"""
        user_msg = "I have a salary negotiation coming up and I'm nervous. I don't know how much to ask for or how to make my case."
        
        framework = get_framework_for_context(user_msg, "anxious", "career_advancement")
        
        assert "Power Ownership Model" in framework
        # Should include negotiation guidance
        assert "negotiation" in framework.lower() or "negotiate" in framework.lower()
        # Should mention ownership or claiming
        assert "ownership" in framework.lower() or "claim" in framework.lower() or "advocate" in framework.lower()


class TestCourageousLeadershipScenarios:
    """Test Courageous Leadership™ in vulnerable leadership situations"""
    
    def test_building_trust_after_reorg(self):
        """Test framework for building trust after organizational change"""
        user_msg = "After a recent reorganization, my team is anxious and distrustful. They don't feel safe to speak up in meetings anymore."
        
        framework = get_framework_for_context(user_msg, "concerned", "leadership_effectiveness")
        
        assert "Courageous Leadership" in framework
        # Should address trust
        assert "trust" in framework.lower()
        # Should mention vulnerability or authenticity
        assert "vulnerability" in framework.lower() or "authentic" in framework.lower()
        # Should include emotional intelligence
        assert "emotional" in framework.lower() or "empathy" in framework.lower()
    
    def test_admitting_mistake_to_team(self):
        """Test framework for showing vulnerability as a leader"""
        user_msg = "I made a decision that turned out to be wrong and it affected my team. I know I should admit my mistake but I'm afraid of losing their respect."
        
        framework = get_framework_for_context(user_msg, "vulnerable", "leadership_effectiveness")
        
        assert "Courageous Leadership" in framework
        # Should address vulnerability
        assert "vulnerability" in framework.lower() or "vulnerable" in framework.lower()
        # Should mention courage or strength
        assert "courage" in framework.lower() or "strength" in framework.lower()


class TestExecutiveEvolutionScenarios:
    """Test Executive Evolution™ in senior leadership situations"""
    
    def test_360_feedback_derailer(self):
        """Test framework for addressing 360 feedback about derailers"""
        user_msg = "My 360 feedback says I 'add too much value' and 'interrupt people in meetings.' I didn't realize I was doing this and I'm not sure how to change."
        
        framework = get_framework_for_context(user_msg, "reflective", "leadership_effectiveness")
        
        assert "Executive Evolution" in framework
        # Should address derailers or blind spots
        assert "derailer" in framework.lower() or "blind" in framework.lower()
        # Should mention behavior change
        assert "behavior" in framework.lower() or "change" in framework.lower()
        # Should include feedback approach
        assert "feedback" in framework.lower() or "feedforward" in framework.lower()
    
    def test_vp_leadership_transition(self):
        """Test framework for VP transitioning to C-suite"""
        user_msg = "I'm a VP being considered for a C-level role. I know I need to think and act differently at that level but I'm not sure what to change."
        
        framework = get_framework_for_context(user_msg, "ambitious", "career_advancement")
        
        assert "Executive Evolution" in framework
        # Should address executive transition
        assert "executive" in framework.lower()
        # Should mention blind spots or new behaviors
        assert "blind" in framework.lower() or "behavior" in framework.lower() or "evolution" in framework.lower()


class TestFrameworkEffectiveness:
    """Test that frameworks provide actionable, coaching-appropriate guidance"""
    
    def test_frameworks_have_questions_not_just_advice(self):
        """Verify frameworks use coaching questions, not just directive advice"""
        # All frameworks should include question marks (coaching questions)
        scenarios = [
            ("I need to give feedback", "Direct Care Feedback"),
            ("I'm a new manager", "Leadership Foundation"),
            ("I feel like an imposter", "Power Ownership Model"),
            ("I want to be more vulnerable", "Courageous Leadership"),
            ("I'm a VP with 360 feedback", "Executive Evolution"),
        ]
        
        for msg, expected_framework in scenarios:
            framework = get_framework_for_context(msg, "neutral", "professional_growth")
            # Should have questions (indicated by ? or question words)
            has_questions = ("?" in framework or 
                            "ask" in framework.lower() or 
                            "what" in framework.lower() or
                            "how" in framework.lower())
            assert has_questions, f"{expected_framework} should include coaching questions"
    
    def test_frameworks_encourage_exploration_not_quick_fixes(self):
        """Verify frameworks encourage exploration, not just quick fixes"""
        scenarios = [
            "I need help with my team",
            "I'm struggling with confidence",
            "I don't know how to delegate",
        ]
        
        for msg in scenarios:
            framework = get_framework_for_context(msg, "neutral", "professional_growth")
            # Should encourage exploration
            exploration_words = ["explore", "discover", "identify", "reflect", "consider"]
            has_exploration = any(word in framework.lower() for word in exploration_words)
            assert has_exploration, "Framework should encourage exploration"
    
    def test_frameworks_support_client_autonomy(self):
        """Verify frameworks respect client's autonomy and choices"""
        # Frameworks should not be overly directive
        scenarios = [
            "I'm not sure what to do about my career",
            "I have a difficult decision to make",
        ]
        
        for msg in scenarios:
            framework = get_framework_for_context(msg, "uncertain", "professional_growth")
            # Should avoid overly directive language
            overly_directive = ["you must", "you should", "you have to", "you need to"]
            is_overly_directive = any(phrase in framework.lower() for phrase in overly_directive)
            
            # Frameworks can have "you" but should balance with questions
            has_questions = "?" in framework
            
            # Either should not be overly directive OR should have questions to balance
            assert (not is_overly_directive) or has_questions, \
                "Framework should not be overly directive without questions"
    
    def test_frameworks_provide_multiple_options(self):
        """Verify frameworks provide multiple approaches, not just one way"""
        # Frameworks should present options and alternatives
        msg = "I'm having trouble with a team member"
        framework = get_framework_for_context(msg, "frustrated", "professional_growth")
        
        # Should have multiple options (indicated by lists, alternatives, or ranges)
        has_options = (
            framework.count("-") >= 5 or  # Multiple bullet points
            "or" in framework.lower() or  # Alternatives
            "option" in framework.lower() or  # Explicit options
            "try" in framework.lower()  # Multiple approaches to try
        )
        
        assert has_options, "Framework should provide multiple options"


class TestFrameworkIntegrationWithCoachingProcess:
    """Test that frameworks integrate well with coaching conversation flow"""
    
    def test_framework_supports_multi_turn_conversation(self):
        """Test that frameworks support ongoing coaching relationships"""
        # Simulate multi-turn conversation
        turns = [
            ("I'm a new manager struggling with delegation", "first_turn"),
            ("I tried what you suggested but I'm still micromanaging", "follow_up"),
            ("My team is frustrated with my control issues", "deep_dive"),
        ]
        
        for msg, turn_type in turns:
            framework = get_framework_for_context(msg, "uncertain", "leadership_effectiveness")
            
            # Framework should still be relevant
            assert "Leadership Foundation" in framework or len(framework) > 1000
            
            # Should have application guidance
            assert "application" in framework.lower() or "practice" in framework.lower()
    
    def test_framework_adapts_to_emotional_state(self):
        """Test that framework selection considers emotional context"""
        # Same situation, different emotions
        msg = "I need to give difficult feedback"
        
        # Anxious client
        framework_anxious = get_framework_for_context(msg, "anxious", "professional_growth")
        # Confident client
        framework_confident = get_framework_for_context(msg, "confident", "professional_growth")
        
        # Should select appropriate framework
        assert "Direct Care Feedback" in framework_anxious
        assert "Direct Care Feedback" in framework_confident
        
        # Both should be substantial
        assert len(framework_anxious) > 1500
        assert len(framework_confident) > 1500
    
    def test_framework_supports_different_coaching_goals(self):
        """Test that frameworks work for different coaching objectives"""
        base_msg = "I'm having trouble with my team"
        
        # Leadership effectiveness goal
        framework_leadership = get_framework_for_context(
            base_msg, "frustrated", "leadership_effectiveness"
        )
        
        # Career advancement goal (might need different approach)
        framework_career = get_framework_for_context(
            base_msg, "frustrated", "career_advancement"
        )
        
        # Both should provide value
        assert len(framework_leadership) > 1000
        assert len(framework_career) > 1000
        
        # At least one should directly address leadership
        assert ("Leadership Foundation" in framework_leadership or 
                "Leadership Foundation" in framework_career)
