from typing import Dict, List, Optional


def _build_onboarding_summary(profile: Optional[Dict]) -> Optional[str]:
    if not isinstance(profile, dict):
        return None

    onboarding = profile.get("onboarding_profile")
    if not isinstance(onboarding, dict):
        return None

    assessment_answers = onboarding.get("assessment_answers")
    assessment_answers = assessment_answers if isinstance(assessment_answers, dict) else {}

    summary_parts = []

    user_role = onboarding.get("user_role")
    if isinstance(user_role, str) and user_role.strip():
        summary_parts.append(f"self-described role: {user_role.strip()}")

    experience = assessment_answers.get("experience")
    if isinstance(experience, str) and experience.strip():
        summary_parts.append(f"leadership experience: {experience.strip()}")

    challenge = assessment_answers.get("challenge")
    if isinstance(challenge, str) and challenge.strip():
        summary_parts.append(f"initial challenge: {challenge.strip()}")

    goal_area = assessment_answers.get("goal_area")
    if isinstance(goal_area, str) and goal_area.strip():
        summary_parts.append(f"growth area: {goal_area.strip()}")

    first_goal = onboarding.get("first_goal_title")
    if isinstance(first_goal, str) and first_goal.strip():
        summary_parts.append(f"first stated goal: {first_goal.strip()}")

    coaching_style = onboarding.get("selected_coaching_style")
    if isinstance(coaching_style, str) and coaching_style.strip():
        summary_parts.append(f"saved coaching style: {coaching_style.strip()}")

    if not summary_parts:
        return None

    return "Onboarding summary: " + " | ".join(summary_parts)


def build_context_packet(
    user_message: str,
    history: Optional[List[dict]] = None,
    explicit_context: Optional[str] = None,
    profile: Optional[Dict] = None,
) -> str:
    parts = []

    if explicit_context:
        parts.append(f"Explicit context: {explicit_context}")

    if history:
        last_turns = history[-4:]
        compact = " | ".join([f"{m.get('role','user')}: {m.get('content','')[:140]}" for m in last_turns])
        parts.append(f"Recent history: {compact}")

    onboarding_summary = _build_onboarding_summary(profile)
    if onboarding_summary:
        parts.append(onboarding_summary)

    parts.append(f"Latest user message: {user_message}")

    return "\n".join(parts)


def infer_goal_link(user_message: str) -> str:
    t = (user_message or "").lower()

    if any(k in t for k in ["promotion", "vp", "director", "career growth"]):
        return "career_advancement"
    if any(k in t for k in ["team", "manager", "leadership", "stakeholder"]):
        return "leadership_effectiveness"
    if any(k in t for k in ["focus", "productivity", "prioritize", "execution"]):
        return "execution_excellence"

    return "professional_growth"
