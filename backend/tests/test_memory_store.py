import os
import pytest
import psycopg
from app.services import memory_store


@pytest.fixture
def clean_profiles(test_db_url):
    if not test_db_url:
        pytest.skip("DATABASE_URL not set - skipping PostgreSQL tests")
    
    with psycopg.connect(test_db_url) as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM coaching_profiles")
        conn.commit()
    
    yield test_db_url
    
    with psycopg.connect(test_db_url) as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM coaching_profiles")
        conn.commit()


@pytest.fixture
def test_db_url():
    url = os.getenv("DATABASE_URL")
    if not url:
        return None
    return url


class TestMemoryStore:
    def test_load_profile_empty(self, clean_profiles):
        memory_store._store_backend = None
        profile = memory_store.load_profile("u-empty")
        assert profile == {}

    def test_save_and_load_profile(self, clean_profiles):
        memory_store._store_backend = None
        profile = {"goals": ["career_advancement"], "patterns": ["stress_load"]}
        memory_store.save_profile("u1", profile)
        
        loaded = memory_store.load_profile("u1")
        assert loaded["goals"] == ["career_advancement"]
        assert loaded["patterns"] == ["stress_load"]

    def test_update_profile_from_turn(self, clean_profiles):
        memory_store._store_backend = None
        
        updated = memory_store.update_profile_from_turn(
            "u2",
            "I'm overwhelmed and want a promotion",
            "career_advancement",
            style_used="supportive",
            emotion_primary="high_stress",
            context_triggers={"situational_trigger": "deadline_pressure"},
        )
        assert "career_advancement" in updated["goals"]
        assert "stress_load" in updated["patterns"]
        assert updated["emotion_timeline"][-1]["emotion"] == "high_stress"

        memory_store._store_backend = None
        profile2 = memory_store.load_profile("u2")
        assert profile2["goals"] == updated["goals"]
        assert profile2["patterns"] == updated["patterns"]

    def test_profile_persistence_across_loads(self, clean_profiles):
        memory_store._store_backend = None
        
        profile1 = {"goals": ["leadership"], "patterns": ["advancement_focus"]}
        memory_store.save_profile("u3", profile1)
        
        memory_store._store_backend = None
        loaded1 = memory_store.load_profile("u3")
        
        memory_store._store_backend = None
        loaded2 = memory_store.load_profile("u3")
        
        assert loaded1 == loaded2
        assert loaded1["goals"] == ["leadership"]
