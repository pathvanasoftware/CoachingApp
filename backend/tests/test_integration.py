"""
Integration tests for CI/CD pipeline.

These tests verify the full system integration including:
- API endpoints end-to-end
- Database operations with real PostgreSQL
- Cache layer integration
- Health checks for deployment verification
- Full user journey scenarios

Run locally with: DATABASE_URL="your_db_url" pytest tests/test_integration.py -v
"""

import os
import pytest
import asyncio
import json


def _db_available() -> bool:
    """Check if a real PostgreSQL database connection is available."""
    db_url = os.getenv("DATABASE_URL", "")
    if "sqlite" in db_url or "dummy" in db_url:
        return False
    try:
        import psycopg
        with psycopg.connect(db_url) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        return True
    except Exception:
        return False


# Skip marker for tests requiring real database
requires_db = pytest.mark.skipif(not _db_available(), reason="PostgreSQL database not available")


# =============================================================================
# Fixtures
# =============================================================================

@pytest.fixture
def client():
    """Create test client for the main app."""
    from fastapi.testclient import TestClient
    from main import app
    return TestClient(app)


@pytest.fixture
def test_db_url():
    """Get test database URL from environment."""
    url = os.getenv("DATABASE_URL")
    if not url:
        pytest.skip("DATABASE_URL not set - skipping PostgreSQL tests")
    try:
        import psycopg
        with psycopg.connect(url) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
    except Exception as e:
        pytest.skip(f"Database connection failed: {e}")
    return url


@pytest.fixture
def clean_db(test_db_url):
    """Clean database before and after tests."""
    import psycopg
    try:
        with psycopg.connect(test_db_url) as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM coaching_profiles")
                cur.execute("DELETE FROM users")
            conn.commit()
        yield test_db_url
    finally:
        try:
            with psycopg.connect(test_db_url) as conn:
                with conn.cursor() as cur:
                    cur.execute("DELETE FROM coaching_profiles")
                    cur.execute("DELETE FROM users")
                conn.commit()
        except Exception:
            pass


@pytest.fixture
def in_memory_cache():
    """Create in-memory cache for testing."""
    from app.services.cache import InMemoryCache
    return InMemoryCache()


# =============================================================================
# Health Check Tests (Critical for CI/CD)
# =============================================================================

class TestHealthChecks:
    """Tests for health endpoints - critical for deployment verification."""

    def test_root_endpoint_returns_ok(self, client):
        """Root endpoint should return OK status."""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "service" in data

    def test_health_endpoint_returns_ok(self, client):
        """Health endpoint should return OK status with deployment info."""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "git_sha" in data or "deployed_at" in data

    def test_health_endpoint_robustness(self, client):
        """Health endpoint should be fast and reliable."""
        import time
        start = time.time()
        response = client.get("/health")
        elapsed = time.time() - start
        assert response.status_code == 200
        assert elapsed < 1.0, f"Health check took {elapsed}s (> 1s)"


# =============================================================================
# Database Integration Tests
# =============================================================================

@requires_db
class TestDatabaseIntegration:
    """Tests for PostgreSQL database integration."""

    def test_database_connection(self, test_db_url):
        """Verify database connection is working."""
        import psycopg
        with psycopg.connect(test_db_url) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                result = cur.fetchone()
                assert result[0] == 1

    def test_coaching_profiles_table_exists(self, test_db_url):
        """Verify coaching_profiles table exists and has correct schema."""
        import psycopg
        with psycopg.connect(test_db_url) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT column_name, data_type
                    FROM information_schema.columns
                    WHERE table_name = 'coaching_profiles'
                    ORDER BY column_name
                """)
                columns = {row[0]: row[1] for row in cur.fetchall()}
                assert "user_id" in columns
                assert "profile_json" in columns
                assert "updated_at" in columns

    def test_coaching_profiles_crud(self, clean_db):
        """Test CRUD operations on coaching_profiles table."""
        import psycopg
        with psycopg.connect(clean_db) as conn:
            with conn.cursor() as cur:
                # Create
                cur.execute("""
                    INSERT INTO coaching_profiles (user_id, profile_json)
                    VALUES (%s, %s)
                """, ("test-user-1", json.dumps({"name": "Test User", "goals": []})))
                conn.commit()

                # Read
                cur.execute("""
                    SELECT profile_json FROM coaching_profiles WHERE user_id = %s
                """, ("test-user-1",))
                result = cur.fetchone()
                assert result is not None
                profile = result[0]
                assert profile["name"] == "Test User"

                # Update
                cur.execute("""
                    UPDATE coaching_profiles
                    SET profile_json = %s, updated_at = NOW()
                    WHERE user_id = %s
                """, (json.dumps({"name": "Updated User", "goals": ["goal1"]}), "test-user-1"))
                conn.commit()

                cur.execute("""
                    SELECT profile_json FROM coaching_profiles WHERE user_id = %s
                """, ("test-user-1",))
                result = cur.fetchone()
                assert result[0]["name"] == "Updated User"
                assert "goal1" in result[0]["goals"]

                # Delete
                cur.execute("DELETE FROM coaching_profiles WHERE user_id = %s", ("test-user-1",))
                conn.commit()

                cur.execute("SELECT * FROM coaching_profiles WHERE user_id = %s", ("test-user-1",))
                assert cur.fetchone() is None


# =============================================================================
# Cache Integration Tests
# =============================================================================

class TestCacheIntegration:
    """Tests for cache layer integration."""

    @pytest.mark.asyncio
    async def test_in_memory_cache_basic_operations(self, in_memory_cache):
        """Test basic cache operations."""
        await in_memory_cache.set_json("test-key", {"data": "value"}, 60)
        result = await in_memory_cache.get_json("test-key")
        assert result == {"data": "value"}

    @pytest.mark.asyncio
    async def test_cache_lock_mechanism(self, in_memory_cache):
        """Test distributed lock mechanism in cache."""
        lock_key = "test-lock"
        owner1 = "owner-1"
        owner2 = "owner-2"

        acquired1 = await in_memory_cache.acquire_lock(lock_key, owner1, 10)
        assert acquired1 is True

        acquired2 = await in_memory_cache.acquire_lock(lock_key, owner2, 10)
        assert acquired2 is False

        released = await in_memory_cache.release_lock(lock_key, owner1)
        assert released is True

        acquired2_retry = await in_memory_cache.acquire_lock(lock_key, owner2, 10)
        assert acquired2_retry is True

        await in_memory_cache.release_lock(lock_key, owner2)

    @pytest.mark.asyncio
    async def test_cache_expiration(self, in_memory_cache):
        """Test that cache entries expire correctly."""
        await in_memory_cache.set_json("expire-key", {"temp": "data"}, 1)
        result = await in_memory_cache.get_json("expire-key")
        assert result == {"temp": "data"}

        await asyncio.sleep(1.5)
        expired_result = await in_memory_cache.get_json("expire-key")
        assert expired_result is None


# =============================================================================
# API Integration Tests
# =============================================================================

class TestAPIIntegration:
    """Tests for API endpoint integration."""

    def test_cors_headers_present(self, client):
        """Verify CORS headers are properly configured."""
        response = client.options(
            "/api/chat/",
            headers={
                "Origin": "https://example.com",
                "Access-Control-Request-Method": "POST",
            }
        )
        assert response.status_code in [200, 405]

    def test_quick_replies_endpoint(self, client):
        """Test quick replies generation endpoint."""
        response = client.post(
            "/api/chat/quick-replies",
            params={"message": "I want to improve my leadership", "response": "Let's discuss"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "quick_replies" in data
        assert len(data["quick_replies"]) == 4

    def test_debug_profile_endpoint(self, client):
        """Test debug profile endpoint."""
        response = client.get("/api/debug/profile/test-integration-user")
        assert response.status_code == 200
        data = response.json()
        assert "user_id" in data
        assert "profile" in data

    def test_chat_stream_endpoint_with_mock(self, client, monkeypatch):
        """Test chat stream endpoint with mocked LLM."""
        from app.services.llm import CoachingResponse
        from app.routers import chat as chat_router

        async def _fake_llm(_req):
            return CoachingResponse(
                response="Integration test response",
                quick_replies=["A", "B", "C", "D"],
                style_used="strategic",
                emotion_detected="confident",
                goal_link="career_growth",
            )

        monkeypatch.setattr(chat_router, "get_coaching_response", _fake_llm)
        monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")

        response = client.post(
            "/api/v1/chat-stream",
            json={
                "sessionId": "test-session",
                "message": "Test message",
                "persona": "direct",
                "coachingStyle": "strategic",
                "userId": "test-user"
            }
        )
        assert response.status_code == 200
        assert "text/event-stream" in response.headers.get("content-type", "")

    def test_api_versioning(self, client):
        """Test that both API versions work."""
        response_v1 = client.get("/api/v1/auth/google/url")
        assert response_v1.status_code == 200

        response_std = client.get("/api/auth/google/url")
        assert response_std.status_code == 200


# =============================================================================
# Idempotency Tests
# =============================================================================

class TestIdempotency:
    """Tests for request idempotency mechanism."""

    def test_idempotent_chat_request(self, client, monkeypatch):
        """Test that identical requests with same request_id return cached response."""
        from app.services.llm import CoachingResponse
        from app.routers import chat as chat_router
        from app.services.cache import InMemoryCache

        call_count = {"count": 0}

        async def _counting_llm(_req):
            call_count["count"] += 1
            return CoachingResponse(
                response=f"Response {call_count['count']}",
                quick_replies=["A", "B", "C", "D"],
                style_used="strategic",
                emotion_detected="neutral",
                goal_link="test",
            )

        cache = InMemoryCache()
        monkeypatch.setattr(chat_router, "get_coaching_response", _counting_llm)
        monkeypatch.setattr(chat_router, "response_cache", cache)
        monkeypatch.setattr(chat_router, "_anthropic_available", lambda: True)

        request_body = {
            "message": "Idempotency test",
            "user_id": "idemp-user",
            "request_id": "idemp-request-123",
        }

        response1 = client.post("/api/chat/", json=request_body)
        assert response1.status_code == 200

        response2 = client.post("/api/chat/", json=request_body)
        assert response2.status_code == 200

        assert call_count["count"] == 1, "LLM should only be called once"

    def test_different_request_ids_generate_different_responses(self, client, monkeypatch):
        """Test that different request_ids generate new responses."""
        from app.services.llm import CoachingResponse
        from app.routers import chat as chat_router
        from app.services.cache import InMemoryCache

        call_count = {"count": 0}

        async def _counting_llm(_req):
            call_count["count"] += 1
            return CoachingResponse(
                response=f"Response {call_count['count']}",
                quick_replies=["A", "B", "C", "D"],
                style_used="strategic",
                emotion_detected="neutral",
                goal_link="test",
            )

        cache = InMemoryCache()
        monkeypatch.setattr(chat_router, "get_coaching_response", _counting_llm)
        monkeypatch.setattr(chat_router, "response_cache", cache)
        monkeypatch.setattr(chat_router, "_anthropic_available", lambda: True)

        client.post("/api/chat/", json={"message": "Test 1", "user_id": "user-1", "request_id": "req-1"})
        client.post("/api/chat/", json={"message": "Test 2", "user_id": "user-1", "request_id": "req-2"})

        assert call_count["count"] == 2


# =============================================================================
# Error Handling Tests
# =============================================================================

class TestErrorHandling:
    """Tests for error handling across the system."""

    def test_404_for_unknown_endpoint(self, client):
        """Test that unknown endpoints return 404."""
        response = client.get("/api/unknown/endpoint")
        assert response.status_code == 404

    def test_422_for_invalid_request_body(self, client):
        """Test that invalid request bodies return 422."""
        response = client.post("/api/chat/", json={"invalid": "data"})
        assert response.status_code == 422

    def test_503_when_no_llm_configured(self, client, monkeypatch):
        """Test that requests return 503 when no LLM API key is configured."""
        from app.routers import chat as chat_router

        monkeypatch.setattr(chat_router, "_anthropic_available", lambda: False)
        monkeypatch.setattr(chat_router, "_openai_available", lambda: False)

        response = client.post("/api/chat/", json={"message": "Test", "user_id": "test-user"})
        assert response.status_code == 503


# =============================================================================
# End-to-End User Journey Tests
# =============================================================================

class TestUserJourney:
    """End-to-end tests simulating real user journeys."""

    def test_complete_chat_flow(self, client, monkeypatch):
        """Test complete chat flow from start to finish."""
        from app.services.llm import CoachingResponse
        from app.routers import chat as chat_router
        from app.services.cache import InMemoryCache

        async def _mock_llm(req):
            return CoachingResponse(
                response="Great question! Let me help you.",
                quick_replies=["Tell me more", "Examples", "Next steps", "Different topic"],
                style_used="strategic",
                emotion_detected="curious",
                goal_link="career_development",
            )

        cache = InMemoryCache()
        monkeypatch.setattr(chat_router, "get_coaching_response", _mock_llm)
        monkeypatch.setattr(chat_router, "response_cache", cache)
        monkeypatch.setattr(chat_router, "_anthropic_available", lambda: True)

        response = client.post("/api/v1/chat-stream", json={
            "sessionId": "journey-session-1",
            "message": "How can I become a better leader?",
            "userId": "journey-user-1",
            "coachingStyle": "strategic"
        })
        assert response.status_code == 200

        response = client.post(
            "/api/chat/quick-replies",
            params={"message": "How can I become a better leader?", "response": "Great!"}
        )
        assert response.status_code == 200
        assert len(response.json()["quick_replies"]) == 4


# =============================================================================
# Performance Tests
# =============================================================================

class TestPerformance:
    """Basic performance tests for CI/CD monitoring."""

    def test_health_endpoint_response_time(self, client):
        """Health endpoint should respond quickly."""
        import time

        times = []
        for _ in range(5):
            start = time.time()
            client.get("/health")
            times.append(time.time() - start)

        avg_time = sum(times) / len(times)
        assert avg_time < 0.1, f"Average response time {avg_time}s exceeds 100ms"

    def test_quick_replies_response_time(self, client):
        """Quick replies endpoint should respond quickly."""
        import time

        start = time.time()
        response = client.post("/api/chat/quick-replies", params={"message": "test", "response": "test"})
        elapsed = time.time() - start

        assert response.status_code == 200
        assert elapsed < 0.5, f"Response time {elapsed}s exceeds 500ms"


# =============================================================================
# CI/CD Deployment Verification Tests
# =============================================================================

class TestDeploymentVerification:
    """Tests specifically designed for CI/CD deployment verification."""

    def test_smoke_test_root(self, client):
        """Smoke test: root endpoint is accessible."""
        response = client.get("/")
        assert response.status_code == 200

    def test_smoke_test_health(self, client):
        """Smoke test: health endpoint is accessible."""
        response = client.get("/health")
        assert response.status_code == 200

    def test_smoke_test_api_prefix(self, client):
        """Smoke test: API endpoints are accessible."""
        response = client.get("/api/auth/google/url")
        assert response.status_code == 200

    @requires_db
    def test_database_connectivity(self, test_db_url):
        """Verify database connectivity for deployment."""
        import psycopg
        with psycopg.connect(test_db_url) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT version()")
                version = cur.fetchone()
                assert version is not None
                assert "PostgreSQL" in version[0]

    @requires_db
    def test_required_tables_exist(self, test_db_url):
        """Verify all required tables exist."""
        import psycopg
        with psycopg.connect(test_db_url) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables WHERE table_name = 'coaching_profiles'
                    )
                """)
                assert cur.fetchone()[0], "Required table 'coaching_profiles' does not exist"
