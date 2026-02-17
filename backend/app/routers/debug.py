from fastapi import APIRouter
from app.services.memory_store import load_profile

router = APIRouter()


@router.get("/api/debug/profile/{user_id}")
async def get_user_profile(user_id: str):
    """Read-only debug endpoint to inspect persistent coaching memory profile."""
    return {
        "user_id": user_id,
        "profile": load_profile(user_id)
    }
