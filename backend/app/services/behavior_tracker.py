from __future__ import annotations

from datetime import datetime
from typing import Dict, Any


def update_behavior_signals(profile: Dict[str, Any], *, style_used: str, goal_link: str) -> Dict[str, Any]:
    usage = profile.get("style_usage", {})
    usage[style_used] = int(usage.get(style_used, 0)) + 1
    profile["style_usage"] = usage

    goal_counts = profile.get("goal_progress_signals", {})
    goal_counts[goal_link] = int(goal_counts.get(goal_link, 0)) + 1
    profile["goal_progress_signals"] = goal_counts

    sessions = profile.get("session_events", [])
    sessions.append({"ts": datetime.utcnow().isoformat(), "style": style_used, "goal": goal_link})
    profile["session_events"] = sessions[-50:]

    return profile


def style_preference_shift(profile: Dict[str, Any]) -> str:
    usage = profile.get("style_usage", {})
    if not usage:
        return "no_shift"

    top = sorted(usage.items(), key=lambda kv: kv[1], reverse=True)
    if len(top) == 1:
        return f"stable:{top[0][0]}"
    if top[0][1] - top[1][1] <= 1:
        return "blended"
    return f"leaning:{top[0][0]}"
