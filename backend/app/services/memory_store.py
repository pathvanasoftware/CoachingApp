import json
import os
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

MEMORY_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data", "profiles")
_PROFILE_DIR = MEMORY_DIR

_store_backend: Optional[Any] = None


def _get_store_backend():
    global _store_backend
    if _store_backend is not None:
        return _store_backend
    
    store_type = os.getenv("PROFILE_STORE", "").strip().lower()
    database_url = os.getenv("DATABASE_URL", "").strip()
    
    if store_type == "file":
        logger.info("Profile storage: file (forced via PROFILE_STORE=file)")
        _store_backend = "file"
    elif store_type == "postgres" or (not store_type and database_url):
        from app.services.profile_store import ProfileStore
        logger.info("Profile storage: postgres")
        _store_backend = ProfileStore()
    else:
        logger.info("Profile storage: file (default, no DATABASE_URL)")
        _store_backend = "file"
    
    return _store_backend


def _profile_path(user_id: str) -> str:
    os.makedirs(MEMORY_DIR, exist_ok=True)
    safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in user_id)
    return os.path.join(MEMORY_DIR, f"{safe}.json")


def load_profile(user_id: str) -> Dict[str, Any]:
    backend = _get_store_backend()
    
    if backend == "file":
        path = _profile_path(user_id)
        if not os.path.exists(path):
            return {}
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    else:
        result = backend.get_profile(user_id)
        return result if result is not None else {}


def save_profile(user_id: str, profile: Dict[str, Any]) -> None:
    backend = _get_store_backend()
    
    if backend == "file":
        os.makedirs(MEMORY_DIR, exist_ok=True)
        path = _profile_path(user_id)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(profile, f, ensure_ascii=False, indent=2)
    else:
        backend.save_profile(user_id, profile)


def update_profile_from_turn(
    user_id: str,
    user_message: str,
    goal_link: str,
    style_used: str,
    emotion_primary: str,
    context_triggers: dict,
) -> Dict[str, Any]:
    profile = load_profile(user_id) or {}
    profile.setdefault("goals", [])
    profile.setdefault("patterns", [])
    profile.setdefault("last_topics", [])
    profile.setdefault("emotion_timeline", [])
    profile.setdefault("session_events", [])
    
    if goal_link and goal_link not in profile["goals"]:
        profile["goals"].append(goal_link)
    
    patterns = set(profile.get("patterns", []))
    text = (user_message or "").lower()
    if any(k in text for k in ["stuck", "overwhelmed", "burnout", "anxious"]):
        patterns.add("stress_load")
    if any(k in text for k in ["promotion", "vp", "director", "career"]):
        patterns.add("advancement_focus")
    if any(k in text for k in ["team", "stakeholder", "manager", "leadership"]):
        patterns.add("leadership_scope")
    profile["patterns"] = sorted(patterns)

    timeline = profile.get("emotion_timeline", [])
    timeline.append({
        "emotion": emotion_primary,
        "style": style_used,
        "goal": goal_link,
        "context": context_triggers or {},
    })
    profile["emotion_timeline"] = timeline[-40:]

    save_profile(user_id, profile)
    return profile
