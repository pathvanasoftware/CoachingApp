import json
import os
from typing import Dict, Any

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
MEMORY_DIR = os.path.join(BASE_DIR, "data", "memory")


def _ensure_dir() -> None:
    os.makedirs(MEMORY_DIR, exist_ok=True)


def _path_for(user_id: str) -> str:
    safe = (user_id or "anonymous").replace("/", "_")
    return os.path.join(MEMORY_DIR, f"{safe}.json")


def load_profile(user_id: str) -> Dict[str, Any]:
    _ensure_dir()
    path = _path_for(user_id)
    if not os.path.exists(path):
        return {
            "user_id": user_id,
            "goals": [],
            "patterns": [],
            "preferences": {},
            "last_topics": []
        }

    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
            if isinstance(data, dict):
                return data
    except Exception:
        pass

    return {
        "user_id": user_id,
        "goals": [],
        "patterns": [],
        "preferences": {},
        "last_topics": []
    }


def save_profile(user_id: str, profile: Dict[str, Any]) -> None:
    _ensure_dir()
    path = _path_for(user_id)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(profile, f, ensure_ascii=False, indent=2)


def update_profile_from_turn(user_id: str, user_message: str, goal_link: str) -> Dict[str, Any]:
    profile = load_profile(user_id)

    # simple topic memory
    topics = profile.get("last_topics", [])
    topics.append(user_message[:120])
    profile["last_topics"] = topics[-8:]

    goals = set(profile.get("goals", []))
    if goal_link and goal_link not in ["professional_growth", "wellbeing_first"]:
        goals.add(goal_link)
    profile["goals"] = sorted(goals)

    patterns = set(profile.get("patterns", []))
    text = (user_message or "").lower()
    if any(k in text for k in ["stuck", "overwhelmed", "burnout", "anxious"]):
        patterns.add("stress_load")
    if any(k in text for k in ["promotion", "vp", "director", "career"]):
        patterns.add("advancement_focus")
    if any(k in text for k in ["team", "stakeholder", "manager", "leadership"]):
        patterns.add("leadership_scope")
    profile["patterns"] = sorted(patterns)

    save_profile(user_id, profile)
    return profile
