from app.services import memory_store


def test_memory_store_roundtrip(tmp_path, monkeypatch):
    monkeypatch.setattr(memory_store, "MEMORY_DIR", str(tmp_path))

    profile = memory_store.load_profile("u1")
    assert profile["user_id"] == "u1"
    assert profile["goals"] == []

    updated = memory_store.update_profile_from_turn(
        "u1",
        "I'm overwhelmed and want a promotion",
        "career_advancement",
        style_used="supportive",
        emotion_primary="high_stress",
        context_triggers={"situational_trigger": "deadline_pressure"},
    )
    assert "career_advancement" in updated["goals"]
    assert "stress_load" in updated["patterns"]
    assert updated["emotion_timeline"][-1]["emotion"] == "high_stress"

    profile2 = memory_store.load_profile("u1")
    assert profile2["goals"] == updated["goals"]
