import json
import os
from typing import Dict, Any, Optional


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
