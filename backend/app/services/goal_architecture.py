from __future__ import annotations

from typing import Dict, Any, List


def infer_goal_hierarchy(user_message: str, goal_link: str, profile: Dict[str, Any] | None = None) -> Dict[str, List[str]]:
    t = (user_message or "").lower()
    profile = profile or {}

    strategic: List[str] = []
    tactical: List[str] = []
    daily: List[str] = []

    # Strategic layer (3-12 months)
    if goal_link == "career_advancement" or any(k in t for k in ["promotion", "vp", "director", "career"]):
        strategic += ["Career advancement objective", "Leadership effectiveness improvement"]
    if any(k in t for k in ["org", "stakeholder", "impact", "influence"]):
        strategic += ["Organizational impact target"]
    if any(k in t for k in ["skill", "learn", "develop"]):
        strategic += ["Skill development priority"]

    # Tactical layer (1-6 weeks)
    if any(k in t for k in ["project", "deliver", "roadmap", "plan"]):
        tactical += ["Specific project outcome"]
    if any(k in t for k in ["team", "manager", "1:1", "delegate"]):
        tactical += ["Team development objective"]
    if any(k in t for k in ["communication", "presentation", "message"]):
        tactical += ["Communication improvement target"]
    if any(k in t for k in ["process", "workflow", "efficiency", "optimize"]):
        tactical += ["Process optimization target"]

    # Daily action layer (immediate)
    if any(k in t for k in ["meeting", "tomorrow", "today", "prep"]):
        daily += ["Meeting preparation + follow-up"]
    if any(k in t for k in ["difficult conversation", "conflict", "hard talk"]):
        daily += ["Difficult conversation navigation"]
    if any(k in t for k in ["decide", "decision", "tradeoff"]):
        daily += ["Decision-making support"]
    if any(k in t for k in ["stress", "overwhelmed", "anxious", "burnout"]):
        daily += ["Stress regulation technique"]

    # profile-informed defaults
    if not strategic and profile.get("goals"):
        strategic = [g.replace("_", " ").title() for g in profile.get("goals", [])[:2]]

    if not strategic:
        strategic = ["Leadership effectiveness improvement"]
    if not tactical:
        tactical = ["Specific project outcome"]
    if not daily:
        daily = ["Decision-making support"]

    return {
        "strategic": list(dict.fromkeys(strategic))[:3],
        "tactical": list(dict.fromkeys(tactical))[:3],
        "daily": list(dict.fromkeys(daily))[:3],
    }


def build_goal_anchor(goal_link: str, hierarchy: Dict[str, List[str]]) -> str:
    top = hierarchy.get("strategic", ["leadership growth"])[0]
    if goal_link == "career_advancement":
        return f"Anchor this session to career growth: {top}."
    if goal_link == "leadership_effectiveness":
        return f"Anchor this session to leadership impact: {top}."
    return f"Anchor this session to measurable progress: {top}."


def progressive_skill_building(style_used: str, emotion_primary: str) -> Dict[str, Any]:
    micro = {
        "directive": "Use a 3-step decision checklist (context, options, first action).",
        "facilitative": "Use 1 Socratic question chain (What? So what? Now what?).",
        "supportive": "Use 90-second emotional labeling + one confidence reframe.",
        "strategic": "Use 2x2 tradeoff matrix before committing.",
    }.get(style_used, "Use one structured reflection prompt.")

    practice = "Apply this in your next high-stakes conversation."
    if emotion_primary in ["high_stress", "low_confidence"]:
        practice = "Apply this in a low-risk scenario first, then escalate scope."

    return {
        "micro_learning": micro,
        "practice_opportunity": practice,
        "competency_track": "leadership_judgment",
    }


def outcome_prediction(goal_link: str, emotion_primary: str, style_shift: str) -> Dict[str, str]:
    risk = "medium"
    if emotion_primary in ["high_stress", "frustration"]:
        risk = "high"
    elif emotion_primary in ["high_energy", "analytical_mode"]:
        risk = "low"

    trajectory = "improving"
    if risk == "high":
        trajectory = "at_risk"

    recommendation = "Continue current plan with weekly checkpoints."
    if trajectory == "at_risk":
        recommendation = "Use supportive stabilization this week, then re-enter strategic planning."

    return {
        "goal_link": goal_link,
        "trajectory": trajectory,
        "risk_level": risk,
        "style_shift_signal": style_shift,
        "recommendation": recommendation,
    }
