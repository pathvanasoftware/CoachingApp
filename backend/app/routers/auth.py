import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, EmailStr
from typing import Optional

from app.services.auth import (
    user_service,
    create_auth_response,
    create_access_token,
    verify_token,
    get_google_auth_url,
    exchange_google_code,
    verify_apple_token,
)

router = APIRouter()
security = HTTPBearer()


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: Optional[str] = None


class AppleSignInRequest(BaseModel):
    identity_token: str
    nonce: Optional[str] = None


class GoogleCallbackRequest(BaseModel):
    code: str


class RefreshRequest(BaseModel):
    refresh_token: str


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    user_id = verify_token(credentials.credentials)
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return user_id


@router.post("/login")
async def login(request: LoginRequest):
    user = user_service.verify_user_password(request.email, request.password)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return create_auth_response(user)


@router.post("/register")
async def register(request: RegisterRequest):
    existing = user_service.get_user_by_email(request.email)
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    user = user_service.create_user(
        id=str(uuid.uuid4()),
        email=request.email,
        password=request.password,
        full_name=request.full_name,
    )
    return create_auth_response(user)


@router.post("/apple")
async def apple_signin(request: AppleSignInRequest):
    apple_user = await verify_apple_token(request.identity_token)
    if not apple_user:
        raise HTTPException(status_code=401, detail="Invalid Apple identity token")
    
    apple_id = apple_user.get("sub")
    email = apple_user.get("email")
    
    # Check if user exists
    user = user_service.get_user_by_apple_id(apple_id)
    if not user and email:
        user = user_service.get_user_by_email(email)
    
    if not user:
        # Create new user
        user = user_service.create_user(
            id=str(uuid.uuid4()),
            email=email or f"apple_{apple_id}@placeholder.com",
            password=str(uuid.uuid4()),  # Random password for Apple users
            full_name=apple_user.get("name"),
            apple_id=apple_id,
        )
    elif not user_service.get_user_by_apple_id(apple_id):
        # Link Apple ID to existing user
        user = user_service.update_user(user.id, apple_id=apple_id)
    
    return create_auth_response(user)


@router.get("/google/url")
async def google_auth_url(redirect_uri: str):
    if not redirect_uri:
        raise HTTPException(status_code=400, detail="redirect_uri is required")
    
    auth_url = await get_google_auth_url(redirect_uri)
    return {"auth_url": auth_url}


@router.post("/google/callback")
async def google_callback(request: GoogleCallbackRequest):
    """API endpoint for exchanging Google auth code (used by native SDK)"""
    redirect_uri = "http://localhost:8000/auth/google/callback"
    
    google_user = await exchange_google_code(request.code, redirect_uri)
    if not google_user:
        raise HTTPException(status_code=401, detail="Failed to exchange Google auth code")
    
    google_id = google_user.get("id")
    email = google_user.get("email")
    full_name = google_user.get("name")
    
    # Check if user exists
    user = user_service.get_user_by_google_id(google_id)
    if not user and email:
        user = user_service.get_user_by_email(email)
    
    if not user:
        # Create new user
        user = user_service.create_user(
            id=str(uuid.uuid4()),
            email=email or f"google_{google_id}@placeholder.com",
            password=str(uuid.uuid4()),  # Random password for Google users
            full_name=full_name,
            google_id=google_id,
        )
    elif not user_service.get_user_by_google_id(google_id):
        # Link Google ID to existing user
        user = user_service.update_user(user.id, google_id=google_id)
    
    return create_auth_response(user)


@router.get("/google/callback")
async def google_callback_get(code: str):
    """Handle OAuth redirect from Google - returns HTML that redirects to app with tokens"""
    redirect_uri = "http://localhost:8000/auth/google/callback"
    
    google_user = await exchange_google_code(code, redirect_uri)
    if not google_user:
        return HTMLResponse(content="<html><body><h1>Authentication failed</h1></body></html>", status_code=401)
    
    google_id = google_user.get("id")
    email = google_user.get("email")
    full_name = google_user.get("name")
    
    # Check if user exists
    user = user_service.get_user_by_google_id(google_id)
    if not user and email:
        user = user_service.get_user_by_email(email)
    
    if not user:
        # Create new user
        user = user_service.create_user(
            id=str(uuid.uuid4()),
            email=email or f"google_{google_id}@placeholder.com",
            password=str(uuid.uuid4()),
            full_name=full_name,
            google_id=google_id,
        )
    elif not user_service.get_user_by_google_id(google_id):
        # Link Google ID to existing user
        user = user_service.update_user(user.id, google_id=google_id)
    
    auth_response = create_auth_response(user)
    access_token = auth_response["access_token"]
    refresh_token = auth_response["refresh_token"]
    
    # Return HTML that redirects to app with tokens
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Redirecting to Ascendra...</title>
    </head>
    <body>
        <script>
            window.location.href = "com.pathvana.ascendra://auth-callback?access_token={access_token}&refresh_token={refresh_token}";
        </script>
        <p>Redirecting to Ascendra app...</p>
    </body>
    </html>
    """
    return HTMLResponse(content=html)


@router.post("/logout")
async def logout(user_id: str = Depends(get_current_user)):
    return {"message": "Logged out successfully"}


@router.get("/me")
async def get_me(user_id: str = Depends(get_current_user)):
    user = user_service.get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user.to_dict()


@router.post("/refresh")
async def refresh_token(request: RefreshRequest):
    user_id = verify_token(request.refresh_token, expected_type="refresh")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
    
    user = user_service.get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {
        "access_token": create_access_token(user_id),
        "refresh_token": request.refresh_token,  # Keep same refresh token
    }
