import pytest
import tempfile
import os
from typing import Optional
from fastapi.testclient import TestClient
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers.auth import router as auth_router
from app.services.auth import user_service, UserService


@pytest.fixture
def app():
    with tempfile.TemporaryDirectory() as tmpdir:
        db_path = os.path.join(tmpdir, "test_users.db")
        original_db_path = user_service.db_path
        user_service.db_path = db_path
        user_service._ensure_db()
        
        app = FastAPI(title="Test App", version="1.0.0")
        app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
        app.include_router(auth_router, prefix="/api/auth", tags=["Auth"])
        
        yield app
        
        user_service.db_path = original_db_path


@pytest.fixture
def client(app):
    return TestClient(app)


class TestAuthRegister:
    def test_register_success(self, client):
        response = client.post(
            "/api/auth/register",
            json={
                "email": "newuser@example.com",
                "password": "securepassword123",
                "full_name": "New User",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert "user" in data
        assert data["user"]["email"] == "newuser@example.com"
        assert data["user"]["full_name"] == "New User"

    def test_register_duplicate_email(self, client):
        client.post(
            "/api/auth/register",
            json={
                "email": "duplicate@example.com",
                "password": "password123",
            },
        )
        response = client.post(
            "/api/auth/register",
            json={
                "email": "duplicate@example.com",
                "password": "password456",
            },
        )
        assert response.status_code == 400
        assert "already registered" in response.json()["detail"].lower()

    def test_register_missing_email(self, client):
        response = client.post(
            "/api/auth/register",
            json={"password": "password123"},
        )
        assert response.status_code == 422

    def test_register_missing_password(self, client):
        response = client.post(
            "/api/auth/register",
            json={"email": "nopass@example.com"},
        )
        assert response.status_code == 422

    def test_register_invalid_email(self, client):
        response = client.post(
            "/api/auth/register",
            json={
                "email": "not-an-email",
                "password": "password123",
            },
        )
        assert response.status_code == 422


class TestAuthLogin:
    def test_login_success(self, client):
        client.post(
            "/api/auth/register",
            json={
                "email": "login@example.com",
                "password": "correctpassword",
            },
        )
        response = client.post(
            "/api/auth/login",
            json={
                "email": "login@example.com",
                "password": "correctpassword",
            },
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["user"]["email"] == "login@example.com"

    def test_login_wrong_password(self, client):
        client.post(
            "/api/auth/register",
            json={
                "email": "wrongpass@example.com",
                "password": "correctpassword",
            },
        )
        response = client.post(
            "/api/auth/login",
            json={
                "email": "wrongpass@example.com",
                "password": "wrongpassword",
            },
        )
        assert response.status_code == 401
        assert "invalid" in response.json()["detail"].lower()

    def test_login_nonexistent_user(self, client):
        response = client.post(
            "/api/auth/login",
            json={
                "email": "nonexistent@example.com",
                "password": "password123",
            },
        )
        assert response.status_code == 401


class TestAuthMe:
    def test_me_success(self, client):
        register_response = client.post(
            "/api/auth/register",
            json={
                "email": "me@example.com",
                "password": "password123",
            },
        )
        token = register_response.json()["access_token"]

        response = client.get(
            "/api/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["email"] == "me@example.com"

    def test_me_no_token(self, client):
        response = client.get("/api/auth/me")
        assert response.status_code == 401

    def test_me_invalid_token(self, client):
        response = client.get(
            "/api/auth/me",
            headers={"Authorization": "Bearer invalid-token"},
        )
        assert response.status_code == 401

    def test_me_expired_token(self, client):
        response = client.get(
            "/api/auth/me",
            headers={"Authorization": "Bearer expired.token.here"},
        )
        assert response.status_code == 401


class TestAuthRefresh:
    def test_refresh_success(self, client):
        register_response = client.post(
            "/api/auth/register",
            json={
                "email": "refresh@example.com",
                "password": "password123",
            },
        )
        refresh_token = register_response.json()["refresh_token"]

        response = client.post(
            "/api/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data

    def test_refresh_with_access_token_fails(self, client):
        register_response = client.post(
            "/api/auth/register",
            json={
                "email": "refresh2@example.com",
                "password": "password123",
            },
        )
        access_token = register_response.json()["access_token"]

        response = client.post(
            "/api/auth/refresh",
            json={"refresh_token": access_token},
        )
        assert response.status_code == 401

    def test_refresh_invalid_token(self, client):
        response = client.post(
            "/api/auth/refresh",
            json={"refresh_token": "invalid-token"},
        )
        assert response.status_code == 401


class TestAuthLogout:
    def test_logout_success(self, client):
        register_response = client.post(
            "/api/auth/register",
            json={
                "email": "logout@example.com",
                "password": "password123",
            },
        )
        token = register_response.json()["access_token"]

        response = client.post(
            "/api/auth/logout",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        assert "logged out" in response.json()["message"].lower()


class TestGoogleOAuth:
    def test_google_auth_url(self, client):
        response = client.get(
            "/api/auth/google/url",
            params={"redirect_uri": "com.test.app://callback"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "auth_url" in data
        assert "accounts.google.com" in data["auth_url"]
        assert "com.test.app" in data["auth_url"]

    def test_google_auth_url_missing_redirect(self, client):
        response = client.get("/api/auth/google/url")
        assert response.status_code == 200
        data = response.json()
        assert "auth_url" in data

    def test_google_callback_invalid_code(self, client):
        response = client.post(
            "/api/auth/google/callback",
            json={"code": "invalid-auth-code"},
        )
        assert response.status_code == 401


class TestAppleSignIn:
    def test_apple_signin_invalid_token(self, client):
        response = client.post(
            "/api/auth/apple",
            json={"identity_token": "invalid-apple-token"},
        )
        assert response.status_code == 401

    def test_apple_signin_success_with_nonce(self, client, monkeypatch):
        async def _fake_verify(identity_token: str, expected_nonce: Optional[str] = None):
            assert identity_token == "valid-apple-token"
            assert expected_nonce == "nonce-123"
            return {
                "sub": "apple-sub-123",
                "email": "apple.user@example.com",
                "name": "Apple User",
                "nonce": "nonce-123",
            }

        monkeypatch.setattr("app.routers.auth.verify_apple_token", _fake_verify)

        response = client.post(
            "/api/auth/apple",
            json={"identity_token": "valid-apple-token", "nonce": "nonce-123"},
        )
        assert response.status_code == 200
        body = response.json()
        assert "access_token" in body
        assert "refresh_token" in body
        assert body["user"]["email"] == "apple.user@example.com"


class TestFullAuthFlow:
    def test_complete_auth_flow(self, client):
        # 1. Register
        register_response = client.post(
            "/api/auth/register",
            json={
                "email": "flow@example.com",
                "password": "password123",
                "full_name": "Flow User",
            },
        )
        assert register_response.status_code == 200
        tokens = register_response.json()
        access_token = tokens["access_token"]
        refresh_token = tokens["refresh_token"]

        # 2. Get current user
        me_response = client.get(
            "/api/auth/me",
            headers={"Authorization": f"Bearer {access_token}"},
        )
        assert me_response.status_code == 200
        assert me_response.json()["email"] == "flow@example.com"

        # 3. Refresh token
        refresh_response = client.post(
            "/api/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        assert refresh_response.status_code == 200
        new_access_token = refresh_response.json()["access_token"]

        # 4. Use new access token
        me_response2 = client.get(
            "/api/auth/me",
            headers={"Authorization": f"Bearer {new_access_token}"},
        )
        assert me_response2.status_code == 200

        # 5. Logout
        logout_response = client.post(
            "/api/auth/logout",
            headers={"Authorization": f"Bearer {new_access_token}"},
        )
        assert logout_response.status_code == 200
