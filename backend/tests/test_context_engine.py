from app.services.context_engine import build_context_packet


def test_build_context_packet_includes_onboarding_summary():
    profile = {
        "onboarding_profile": {
            "user_role": "Manager / Team Lead",
            "selected_coaching_style": "strategic",
            "first_goal_title": "Improve executive presence",
            "assessment_answers": {
                "experience": "5-10 years",
                "challenge": "Managing up and stakeholder relationships",
                "goal_area": "Communication skills",
            },
        }
    }

    packet = build_context_packet(
        "I need help preparing for my 1:1",
        history=[{"role": "assistant", "content": "What matters most?"}],
        explicit_context="session_id=s-test",
        profile=profile,
    )

    assert "Onboarding summary:" in packet
    assert "Managing up and stakeholder relationships" in packet
    assert "Improve executive presence" in packet
