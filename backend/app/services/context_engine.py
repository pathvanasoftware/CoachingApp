from typing import List, Optional


def build_context_packet(user_message: str, history: Optional[List[dict]] = None, explicit_context: Optional[str] = None) -> str:
    parts = []

    if explicit_context:
        parts.append(f"Explicit context: {explicit_context}")

    if history:
        last_turns = history[-4:]
        compact = " | ".join([f"{m.get('role','user')}: {m.get('content','')[:140]}" for m in last_turns])
        parts.append(f"Recent history: {compact}")

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
