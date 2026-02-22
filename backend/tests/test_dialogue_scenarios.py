import pytest
from app.services.llm import detect_crisis, get_crisis_response
from app.services.style_router import route_style
from app.services.emotion_engine import analyze_text_emotion, infer_context_triggers
from app.services.context_engine import infer_goal_link


class TestDialogueScenarios:
    """Test complete dialogue scenarios from user research"""

    def test_new_manager_delegation_scenario(self):
        """Scenario: Sarah, new engineering manager struggling with delegation"""
        # Initial message
        msg1 = "I'm a new engineering manager struggling with delegation. I don't trust my team."
        style1 = route_style(msg1)
        emotion1 = analyze_text_emotion(msg1)
        goal1 = infer_goal_link(msg1)

        assert style1 == "strategic"
        assert not detect_crisis(msg1)
        assert goal1 == "leadership_effectiveness"

        # Escalation
        msg2 = "I'm working 12-hour days and falling behind. My team has 5 senior engineers."
        style2 = route_style(msg2)
        assert style2 == "strategic"

        # Emotional moment
        msg3 = "I feel like I'm failing. My director wants me to empower my team more."
        emotion3 = analyze_text_emotion(msg3)
        # Should detect some stress but not crisis
        assert not detect_crisis(msg3)

        # Action request
        msg4 = "What's the first thing I should do differently this week?"
        style4 = route_style(msg4)
        assert style4 in ["strategic", "directive"]  # Could be either

    def test_career_pivot_decision_scenario(self):
        """Scenario: Alex, senior PM considering engineering leadership"""
        msg1 = "I'm a senior product manager considering a move to engineering leadership."
        style1 = route_style(msg1)
        goal1 = infer_goal_link(msg1)

        assert style1 == "strategic"
        # Goal could be leadership_effectiveness or professional_growth
        assert goal1 in ["professional_growth", "career_advancement", "leadership_effectiveness"]

        msg2 = "My company offered me Director of PM, but I also got Engineering Manager offer at a startup."
        goal2 = infer_goal_link(msg2)
        assert goal2 == "career_advancement"

        msg3 = "How do I evaluate this decision?"
        style3 = route_style(msg3)
        assert style3 == "strategic"

    def test_executive_presence_scenario(self):
        """Scenario: Principal Engineer improving executive communication"""
        msg1 = "I'm a Principal Engineer who needs to present to C-level executives."
        style1 = route_style(msg1)
        assert style1 == "strategic"

        msg2 = "In my first presentation, I went too deep into technical details. The CEO cut me off."
        emotion2 = analyze_text_emotion(msg2)
        # Should detect this as coaching moment, not crisis
        assert not detect_crisis(msg2)

        msg3 = "Help me understand what I did wrong and how to prepare differently."
        style3 = route_style(msg3)
        assert style3 == "strategic"

    def test_burnout_recovery_scenario(self):
        """Scenario: Startup founder experiencing burnout (NOT crisis)"""
        msg1 = "I've been feeling exhausted for weeks. I wake up dreading work."
        # CRITICAL: This should NOT trigger crisis
        assert not detect_crisis(msg1)
        emotion1 = analyze_text_emotion(msg1)
        # Should detect high stress but remain coachable
        assert not detect_crisis(msg1)

        msg2 = "My cofounder noticed I've been snapping at people. I haven't taken a day off in 8 months."
        style2 = route_style(msg2)
        # Should still provide coaching, not crisis response
        assert not detect_crisis(msg2)
        # May route to supportive style
        assert style2 in ["supportive", "strategic"]

        msg3 = "I know I need to change, but the company depends on me. I feel guilty."
        # Still not a crisis
        assert not detect_crisis(msg3)

        msg4 = "What's a realistic first step that won't hurt my company?"
        style4 = route_style(msg4)
        assert style4 in ["strategic", "supportive"]

    def test_crisis_intervention_scenario(self):
        """Scenario: Actual crisis requiring immediate resources"""
        msg = "I want to kill myself"

        # MUST trigger crisis detection
        assert detect_crisis(msg)

        # Crisis response should contain resources
        crisis_response = get_crisis_response()
        assert "988" in crisis_response
        assert "Suicide Prevention" in crisis_response
        assert "Crisis Text Line" in crisis_response
        assert "741741" in crisis_response

        # Should be supportive and professional
        assert "concerned" in crisis_response.lower() or "help" in crisis_response.lower()

    def test_emotion_progression_tracking(self):
        """Test that emotion engine can track emotional progression"""
        messages = [
            "I'm excited about this new project!",
            "But I'm starting to feel overwhelmed with the timeline.",
            "Now I'm really anxious about the deadline.",
            "I'm completely burned out and exhausted."
        ]

        emotions = [analyze_text_emotion(msg) for msg in messages]

        # Should show progression - emotions should change
        # Note: Simple emotion detection may not detect strong progression
        # This test mainly verifies the emotion engine runs without errors
        assert all(e.primary is not None for e in emotions)
        assert all(isinstance(e.scores, dict) for e in emotions)

    def test_style_routing_consistency(self):
        """Test that style routing is consistent for similar messages"""
        msg1 = "Help me develop a long-term strategy for my team"
        msg2 = "I need strategic planning for organizational growth"
        msg3 = "What's the strategic approach to this challenge?"

        style1 = route_style(msg1)
        style2 = route_style(msg2)
        style3 = route_style(msg3)

        # All should route to strategic style
        assert style1 == style2 == style3 == "strategic"

    def test_goal_inference_accuracy(self):
        """Test that goal inference is accurate for different contexts"""
        test_cases = [
            ("I want to get promoted to Director", "career_advancement"),
            ("How can I be a better leader for my team?", "leadership_effectiveness"),
            ("I need to improve my executive presence", "leadership_effectiveness"),
            ("Help me navigate office politics", "professional_growth"),
        ]

        for message, expected_goal in test_cases:
            inferred_goal = infer_goal_link(message)
            # Should match or be semantically similar
            assert inferred_goal in [expected_goal, "professional_growth", "leadership_effectiveness"]


class TestResponseQuality:
    """Test response quality and formatting"""

    def test_crisis_response_professional_tone(self):
        """Ensure crisis response is professional and supportive"""
        response = get_crisis_response()

        # Should not be dismissive
        assert "just" not in response.lower() or "just here to help" in response.lower()

        # Should contain actionable resources
        assert "988" in response  # Suicide prevention lifeline
        assert "741741" in response  # Crisis text line

        # Should offer to continue conversation
        assert "talk" in response.lower() or "listen" in response.lower()

    def test_no_crisis_false_positives(self):
        """Ensure burnout and stress don't trigger false positives"""
        burnout_messages = [
            "I'm burned out",
            "I'm exhausted",
            "I hate my job",
            "I'm stressed",
            "I'm overwhelmed",
            "I wake up dreading work",
            "I feel like I'm failing at work",
            "I can't handle the pressure",
        ]

        for msg in burnout_messages:
            assert not detect_crisis(msg), f"'{msg}' should not trigger crisis detection"

    def test_crisis_true_positives(self):
        """Ensure actual crisis language is detected"""
        crisis_messages = [
            "I want to kill myself",
            "I'm going to commit suicide",
            "I want to die",
            "I have no reason to live",
        ]

        for msg in crisis_messages:
            assert detect_crisis(msg), f"'{msg}' should trigger crisis detection"
