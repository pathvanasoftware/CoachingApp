import json
import os
from typing import Dict, Any, Optional

MEMORY_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data", "profiles")
_PROFILE_DIR = MEMORY_DIR


def _profile_path(user_id: str) -> str:
    os.makedirs(MEMORY_DIR, exist_ok=True)
    safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in user_id)
    return os.path.join(MEMORY_DIR, f"{safe}.json")


def _default_profile(user_id: str) -> Dict[str, Any]:
    return {
        "user_id": user_id,
        "goals": [],
        "patterns": [],
        "last_topics": [],
        "emotion_timeline": [],
        "session_events": [],
        "escalation_risk": "none",
    }


def load_profile(user_id: str) -> Dict[str, Any]:
    path = _profile_path(user_id)
    if os.path.exists(path):
        try:
            with open(path) as f:
                return json.load(f)
        except Exception:
            pass
    return _default_profile(user_id)


def save_profile(user_id: str, profile: Dict[str, Any]) -> None:
    path = _profile_path(user_id)
    try:
        with open(path, "w") as f:
            json.dump(profile, f, ensure_ascii=False, indent=2)
    except Exception:
        pass


def update_profile_from_turn(
    user_id: str,
    user_message: str,
    goal_link: str,
    *,
    style_used: str = "strategic",
    emotion_primary: str = "neutral",
    context_triggers: Optional[Dict[str, str]] = None,
) -> Dict[str, Any]:
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
