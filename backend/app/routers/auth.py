import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, EmailStr
from typing import Dict, Optional

from app.services.auth import (
    user_service,
    create_auth_response,
    create_access_token,
    verify_token,
    get_google_auth_url,
    exchange_google_code,
    verify_apple_token,
    GOOGLE_REDIRECT_URI,
)
from app.services.entitlements import entitlement_service
from app.services.profile_store import get_profile_store

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


class UpdateMeRequest(BaseModel):
    full_name: Optional[str] = None
    organization_id: Optional[str] = None
    seat_tier: Optional[str] = None
    preferred_persona: Optional[str] = None
    preferred_input_mode: Optional[str] = None
    has_completed_onboarding: Optional[bool] = None


class OnboardingProfileRequest(BaseModel):
    user_name: Optional[str] = None
    selected_coaching_style: Optional[str] = None
    first_goal_title: Optional[str] = None
    first_goal_description: Optional[str] = None
    assessment_answers: Dict[str, str] = {}
    user_role: Optional[str] = None


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
    apple_user = await verify_apple_token(request.identity_token, expected_nonce=request.nonce)
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
async def google_auth_url(redirect_uri: Optional[str] = None):
    effective_redirect_uri = redirect_uri or GOOGLE_REDIRECT_URI
    auth_url = await get_google_auth_url(effective_redirect_uri)
    return {"auth_url": auth_url}


@router.post("/google/callback")
async def google_callback(request: GoogleCallbackRequest):
    """API endpoint for exchanging Google auth code (used by native SDK)"""
    redirect_uri = GOOGLE_REDIRECT_URI
    
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
    redirect_uri = GOOGLE_REDIRECT_URI
    
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
    # Using meta refresh as fallback (more reliable than JS in ASWebAuthenticationSession)
    app_url = f"com.pathvana.ascendra://auth-callback?access_token={access_token}&refresh_token={refresh_token}"
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta http-equiv="refresh" content="0;url={app_url}">
        <title>Redirecting to Ascendra...</title>
        <script>
            window.location.href = "{app_url}";
        </script>
    </head>
    <body>
        <p>Redirecting to Ascendra app...</p>
        <p><a href="{app_url}">Click here if not redirected</a></p>
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

    user_dict = user.to_dict()

    # Include role_level from profile if available
    from app.services.profile_store import get_profile_store
    profile_store = get_profile_store()
    profile = profile_store.get_profile(user_id)
    if profile and "role_level" in profile:
        user_dict["role_level"] = profile["role_level"]
    if profile and "onboarding_profile" in profile:
        user_dict["onboarding_profile"] = profile["onboarding_profile"]

    return user_dict


@router.get("/entitlements")
async def get_entitlements(user_id: str = Depends(get_current_user)):
    return entitlement_service.describe(user_id)


@router.patch("/me")
async def update_me(request: UpdateMeRequest, user_id: str = Depends(get_current_user)):
    updates = request.dict(exclude_none=True)

    user = user_service.get_user_by_id(user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if not updates:
        return user.to_dict()

    updated = user_service.update_user(user_id, **updates)
    if not updated:
        raise HTTPException(status_code=500, detail="Failed to update user")
    return updated.to_dict()


@router.patch("/me/role-level")
async def update_role_level(
    role_level: str,
    user_id: str = Depends(get_current_user)
):
    """Update the user's role level for role-aware coaching.

    Valid values: individual_contributor, manager, director, vp, c_suite
    """
    valid_levels = ["individual_contributor", "manager", "director", "vp", "c_suite"]
    if role_level not in valid_levels:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid role_level. Must be one of: {', '.join(valid_levels)}"
        )

    profile_store = get_profile_store()
    profile_store.update_role_level(user_id, role_level)

    # Return updated profile with role_level
    profile = profile_store.get_profile(user_id) or {}
    return {"role_level": role_level, **profile}


@router.patch("/me/onboarding-profile")
async def update_onboarding_profile(
    request: OnboardingProfileRequest,
    user_id: str = Depends(get_current_user)
):
    profile_store = get_profile_store()
    profile = profile_store.get_profile(user_id) or {}

    sanitized_answers = {
        str(key): str(value).strip()
        for key, value in (request.assessment_answers or {}).items()
        if str(key).strip() and str(value).strip()
    }

    onboarding_profile = {
        "user_name": request.user_name.strip() if request.user_name else None,
        "selected_coaching_style": request.selected_coaching_style,
        "first_goal_title": request.first_goal_title.strip() if request.first_goal_title else "",
        "first_goal_description": request.first_goal_description.strip() if request.first_goal_description else "",
        "assessment_answers": sanitized_answers,
        "user_role": request.user_role.strip() if request.user_role else None,
    }

    profile["onboarding_profile"] = onboarding_profile
    profile_store.save_profile(user_id, profile)

    return {"onboarding_profile": onboarding_profile}


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
