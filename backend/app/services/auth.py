import os
import json
import secrets
import hashlib
from urllib.parse import urlencode
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any
import jwt
import bcrypt
import httpx
import psycopg
from psycopg.rows import dict_row


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, hashed: str) -> bool:
    if isinstance(hashed, str):
        return bcrypt.checkpw(password.encode("utf-8"), hashed.encode("utf-8"))
    else:
        return bcrypt.checkpw(password.encode("utf-8"), hashed)

JWT_SECRET = os.getenv("JWT_SECRET", secrets.token_urlsafe(32))
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15
REFRESH_TOKEN_EXPIRE_DAYS = 7

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET", "")
GOOGLE_REDIRECT_URI = os.getenv(
    "GOOGLE_REDIRECT_URI",
    "https://coachingapp-backend-production.up.railway.app/api/auth/google/callback",
)


class User:
    def __init__(
        self,
        id: str,
        email: str,
        full_name: Optional[str] = None,
        organization_id: Optional[str] = None,
        seat_tier: str = "starter",
        preferred_persona: str = "direct_challenger",
        preferred_input_mode: str = "text",
        has_completed_onboarding: bool = False,
        created_at: Optional[datetime] = None,
        updated_at: Optional[datetime] = None,
    ):
        self.id = id
        self.email = email
        self.full_name = full_name
        self.organization_id = organization_id
        self.seat_tier = seat_tier
        self.preferred_persona = preferred_persona
        self.preferred_input_mode = preferred_input_mode
        self.has_completed_onboarding = has_completed_onboarding
        self.created_at = created_at or datetime.now(timezone.utc)
        self.updated_at = updated_at or datetime.now(timezone.utc)

    def to_dict(self) -> dict:
        persona = self.preferred_persona
        if persona == "directChallenger":
            persona = "direct_challenger"
        elif persona == "supportiveStrategist":
            persona = "supportive_strategist"
        return {
            "id": self.id,
            "email": self.email,
            "full_name": self.full_name,
            "organization_id": self.organization_id,
            "seat_tier": self.seat_tier,
            "preferred_persona": persona,
            "preferred_input_mode": self.preferred_input_mode,
            "has_completed_onboarding": self.has_completed_onboarding,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }


class UserService:
    def __init__(self, database_url: Optional[str] = None):
        self.database_url = database_url or os.getenv("DATABASE_URL")
        if not self.database_url:
            raise RuntimeError("DATABASE_URL environment variable is required for auth persistence")
        self._ensure_db()

    def _ensure_db(self):
        with psycopg.connect(self.database_url) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS users (
                        id TEXT PRIMARY KEY,
                        email TEXT UNIQUE NOT NULL,
                        password_hash TEXT NOT NULL,
                        full_name TEXT,
                        organization_id TEXT,
                        seat_tier TEXT DEFAULT 'starter',
                        preferred_persona TEXT DEFAULT 'direct_challenger',
                        preferred_input_mode TEXT DEFAULT 'text',
                        has_completed_onboarding BOOLEAN DEFAULT FALSE,
                        created_at TIMESTAMPTZ,
                        updated_at TIMESTAMPTZ,
                        google_id TEXT UNIQUE,
                        apple_id TEXT UNIQUE
                    )
                """)
            conn.commit()

    def _get_conn(self):
        return psycopg.connect(self.database_url)

    def create_user(
        self,
        id: str,
        email: str,
        password: str,
        full_name: Optional[str] = None,
        google_id: Optional[str] = None,
        apple_id: Optional[str] = None,
    ) -> User:
        password_hash = hash_password(password)
        now = datetime.now(timezone.utc)
        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """INSERT INTO users 
                       (id, email, password_hash, full_name, google_id, apple_id, created_at, updated_at)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
                    (id, email, password_hash, full_name, google_id, apple_id, now, now),
                )
            conn.commit()
        return self.get_user_by_id(id)

    def get_user_by_id(self, id: str) -> Optional[User]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute("SELECT * FROM users WHERE id = %s", (id,))
                row = cur.fetchone()
        if not row:
            return None
        return self._row_to_user(row)

    def get_user_by_email(self, email: str) -> Optional[User]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute("SELECT * FROM users WHERE email = %s", (email,))
                row = cur.fetchone()
        if not row:
            return None
        return self._row_to_user(row)

    def get_user_by_google_id(self, google_id: str) -> Optional[User]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute("SELECT * FROM users WHERE google_id = %s", (google_id,))
                row = cur.fetchone()
        if not row:
            return None
        return self._row_to_user(row)

    def get_user_by_apple_id(self, apple_id: str) -> Optional[User]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute("SELECT * FROM users WHERE apple_id = %s", (apple_id,))
                row = cur.fetchone()
        if not row:
            return None
        return self._row_to_user(row)

    def verify_user_password(self, email: str, password: str) -> Optional[User]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute("SELECT * FROM users WHERE email = %s", (email,))
                row = cur.fetchone()
        if not row:
            return None
        password_hash = row["password_hash"]
        if verify_password(password, password_hash):
            return self._row_to_user(row)
        return None

    def update_user(self, id: str, **kwargs) -> Optional[User]:
        updates = []
        values = []
        for key, value in kwargs.items():
            if key in ["full_name", "organization_id", "seat_tier", "preferred_persona", 
                       "preferred_input_mode", "has_completed_onboarding", "google_id", "apple_id"]:
                updates.append(f"{key} = %s")
                values.append(value)
        if not updates:
            return self.get_user_by_id(id)
        updates.append("updated_at = %s")
        values.append(datetime.now(timezone.utc))
        values.append(id)
        with self._get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    f"UPDATE users SET {', '.join(updates)} WHERE id = %s",
                    values,
                )
            conn.commit()
        return self.get_user_by_id(id)

    def _row_to_user(self, row: dict) -> User:
        return User(
            id=row["id"],
            email=row["email"],
            full_name=row.get("full_name"),
            organization_id=row.get("organization_id"),
            seat_tier=row.get("seat_tier") or "starter",
            preferred_persona=row.get("preferred_persona") or "direct_challenger",
            preferred_input_mode=row.get("preferred_input_mode") or "text",
            has_completed_onboarding=bool(row.get("has_completed_onboarding")),
            created_at=row.get("created_at"),
            updated_at=row.get("updated_at"),
        )


user_service = UserService()


def create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    return jwt.encode(
        {"sub": user_id, "exp": expire, "type": "access"},
        JWT_SECRET,
        algorithm=JWT_ALGORITHM,
    )


def create_refresh_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    return jwt.encode(
        {"sub": user_id, "exp": expire, "type": "refresh"},
        JWT_SECRET,
        algorithm=JWT_ALGORITHM,
    )


def verify_token(token: str, expected_type: str = "access") -> Optional[str]:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        if payload.get("type") != expected_type:
            return None
        return payload.get("sub")
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def create_auth_response(user: User) -> dict:
    return {
        "access_token": create_access_token(user.id),
        "refresh_token": create_refresh_token(user.id),
        "user": user.to_dict(),
    }


async def get_google_auth_url(redirect_uri: str) -> str:
    params = {
        "client_id": GOOGLE_CLIENT_ID,
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": "openid email profile",
        "access_type": "offline",
    }
    query = urlencode(params)
    return f"https://accounts.google.com/o/oauth2/v2/auth?{query}"


async def exchange_google_code(code: str, redirect_uri: str) -> Optional[dict]:
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://oauth2.googleapis.com/token",
            data={
                "code": code,
                "client_id": GOOGLE_CLIENT_ID,
                "client_secret": GOOGLE_CLIENT_SECRET,
                "redirect_uri": redirect_uri,
                "grant_type": "authorization_code",
            },
        )
        if response.status_code != 200:
            return None
        tokens = response.json()
        
        # Get user info
        user_response = await client.get(
            "https://www.googleapis.com/oauth2/v2/userinfo",
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
        if user_response.status_code != 200:
            return None
        return user_response.json()


def _nonce_matches(claim_nonce: str, expected_nonce: str) -> bool:
    if not claim_nonce or not expected_nonce:
        return False
    if secrets.compare_digest(claim_nonce, expected_nonce):
        return True
    expected_hash = hashlib.sha256(expected_nonce.encode("utf-8")).hexdigest()
    return secrets.compare_digest(claim_nonce, expected_hash)


async def verify_apple_token(identity_token: str, expected_nonce: Optional[str] = None) -> Optional[dict]:
    import httpx
    async with httpx.AsyncClient() as client:
        response = await client.get("https://appleid.apple.com/auth/keys")
        if response.status_code != 200:
            return None
        keys = response.json()["keys"]
    
    for key in keys:
        try:
            from jwt.algorithms import RSAAlgorithm
            public_key = RSAAlgorithm.from_jwk(json.dumps(key))
            payload = jwt.decode(identity_token, public_key, algorithms=["RS256"], audience="com.pathvana.ascendra")
            if expected_nonce:
                claim_nonce = payload.get("nonce")
                if not isinstance(claim_nonce, str) or not _nonce_matches(claim_nonce, expected_nonce):
                    return None
            return payload
        except jwt.InvalidTokenError:
            continue
    return None
