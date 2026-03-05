import pytest
import os
import asyncio
from datetime import datetime, timezone, timedelta
import psycopg
from psycopg.rows import dict_row

from app.services.auth import (
    UserService,
    User,
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    verify_token,
    create_auth_response,
    get_google_auth_url,
)


@pytest.fixture
def test_db_url():
    url = os.getenv("DATABASE_URL")
    if not url:
        pytest.skip("DATABASE_URL not set - skipping PostgreSQL tests")
    return url


@pytest.fixture
def clean_db(test_db_url):
    with psycopg.connect(test_db_url) as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM users")
        conn.commit()
    yield test_db_url
    with psycopg.connect(test_db_url) as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM users")
        conn.commit()


class TestPasswordHashing:
    def test_hash_and_verify_password(self):
        password = "testpassword123"
        hashed = hash_password(password)
        assert hashed != password
        assert verify_password(password, hashed)

    def test_verify_wrong_password(self):
        password = "testpassword123"
        hashed = hash_password(password)
        assert not verify_password("wrongpassword", hashed)


class TestJWT:
    def test_create_and_verify_access_token(self):
        user_id = "test-user-123"
        token = create_access_token(user_id)
        assert token is not None
        assert isinstance(token, str)

        verified_id = verify_token(token, expected_type="access")
        assert verified_id == user_id

    def test_create_and_verify_refresh_token(self):
        user_id = "test-user-456"
        token = create_refresh_token(user_id)
        assert token is not None

        verified_id = verify_token(token, expected_type="refresh")
        assert verified_id == user_id

    def test_verify_token_wrong_type(self):
        user_id = "test-user-789"
        access_token = create_access_token(user_id)
        
        verified_id = verify_token(access_token, expected_type="refresh")
        assert verified_id is None

    def test_verify_invalid_token(self):
        verified_id = verify_token("invalid-token", expected_type="access")
        assert verified_id is None

    def test_verify_empty_token(self):
        verified_id = verify_token("", expected_type="access")
        assert verified_id is None


class TestUser:
    def test_user_creation(self):
        user = User(
            id="test-id",
            email="test@example.com",
            full_name="Test User",
            seat_tier="professional",
        )
        assert user.id == "test-id"
        assert user.email == "test@example.com"
        assert user.full_name == "Test User"
        assert user.seat_tier == "professional"

    def test_user_to_dict(self):
        user = User(
            id="test-id",
            email="test@example.com",
            full_name="Test User",
        )
        d = user.to_dict()
        assert d["id"] == "test-id"
        assert d["email"] == "test@example.com"
        assert d["full_name"] == "Test User"
        assert d["seat_tier"] == "starter"
        assert "created_at" in d
        assert "updated_at" in d


class TestUserService:
    def test_create_user(self, clean_db):
        service = UserService(database_url=clean_db)
        user = service.create_user(
            id="user-1",
            email="user1@example.com",
            password="password123",
            full_name="User One",
        )
        assert user.id == "user-1"
        assert user.email == "user1@example.com"
        assert user.full_name == "User One"

    def test_get_user_by_id(self, clean_db):
        service = UserService(database_url=clean_db)
        service.create_user(
            id="user-2",
            email="user2@example.com",
            password="password123",
        )
        user = service.get_user_by_id("user-2")
        assert user is not None
        assert user.email == "user2@example.com"

    def test_get_user_by_email(self, clean_db):
        service = UserService(database_url=clean_db)
        service.create_user(
            id="user-3",
            email="user3@example.com",
            password="password123",
        )
        user = service.get_user_by_email("user3@example.com")
        assert user is not None
        assert user.id == "user-3"

    def test_get_nonexistent_user(self, clean_db):
        service = UserService(database_url=clean_db)
        user = service.get_user_by_id("nonexistent")
        assert user is None

    def test_verify_password_correct(self, clean_db):
        service = UserService(database_url=clean_db)
        service.create_user(
            id="user-4",
            email="user4@example.com",
            password="correctpassword",
        )
        user = service.verify_user_password("user4@example.com", "correctpassword")
        assert user is not None
        assert user.id == "user-4"

    def test_verify_password_wrong(self, clean_db):
        service = UserService(database_url=clean_db)
        service.create_user(
            id="user-5",
            email="user5@example.com",
            password="correctpassword",
        )
        user = service.verify_user_password("user5@example.com", "wrongpassword")
        assert user is None

    def test_update_user(self, clean_db):
        service = UserService(database_url=clean_db)
        service.create_user(
            id="user-6",
            email="user6@example.com",
            password="password123",
        )
        updated = service.update_user("user-6", full_name="Updated Name", seat_tier="executive")
        assert updated is not None
        assert updated.full_name == "Updated Name"
        assert updated.seat_tier == "executive"

    def test_duplicate_email_fails(self, clean_db):
        service = UserService(database_url=clean_db)
        service.create_user(
            id="user-7",
            email="duplicate@example.com",
            password="password123",
        )
        with pytest.raises(Exception):
            service.create_user(
                id="user-8",
                email="duplicate@example.com",
                password="password456",
            )

    def test_google_id_operations(self, clean_db):
        service = UserService(database_url=clean_db)
        service.create_user(
            id="user-9",
            email="google@example.com",
            password="password123",
            google_id="google-123",
        )
        user = service.get_user_by_google_id("google-123")
        assert user is not None
        assert user.id == "user-9"

    def test_apple_id_operations(self, clean_db):
        service = UserService(database_url=clean_db)
        service.create_user(
            id="user-10",
            email="apple@example.com",
            password="password123",
            apple_id="apple-456",
        )
        user = service.get_user_by_apple_id("apple-456")
        assert user is not None
        assert user.id == "user-10"


class TestAuthResponse:
    def test_create_auth_response(self):
        user = User(
            id="test-id",
            email="test@example.com",
            full_name="Test User",
        )
        response = create_auth_response(user)
        assert "access_token" in response
        assert "refresh_token" in response
        assert "user" in response
        assert response["user"]["id"] == "test-id"
        assert len(response["access_token"]) > 0
        assert len(response["refresh_token"]) > 0


class TestGoogleOAuth:
    @pytest.mark.asyncio
    async def test_get_google_auth_url(self):
        url = await get_google_auth_url("com.test.app://callback")
        assert "accounts.google.com" in url
        assert "client_id=" in url
        assert "redirect_uri=" in url
        assert "com.test.app" in url
