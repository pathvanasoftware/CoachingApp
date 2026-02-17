from typing import Literal, Optional

CoachingStyle = Literal["directive", "facilitative", "supportive", "strategic"]

STYLE_PROMPTS = {
    "directive": "You are a directive executive coach: clear recommendations, concrete steps, confident tone.",
    "facilitative": "You are a facilitative coach: use Socratic questions to guide discovery and reflection.",
    "supportive": "You are a supportive coach: validate emotions, build confidence, and encourage momentum.",
    "strategic": "You are a strategic coach: zoom out, connect decisions to long-term leadership goals and tradeoffs.",
}


def route_style(user_message: str, preferred_style: Optional[str] = None, emotion: Optional[str] = None) -> CoachingStyle:
    if preferred_style in STYLE_PROMPTS:
        return preferred_style  # explicit user selection wins

    text = (user_message or "").lower()

    if any(k in text for k in ["urgent", "asap", "decision now", "crisis", "immediately"]):
        return "directive"
    if any(k in text for k in ["stuck", "not sure", "what if", "confused", "options"]):
        return "facilitative"
    if any(k in text for k in ["anxious", "burnout", "overwhelmed", "confidence", "afraid"]):
        return "supportive"
    if any(k in text for k in ["strategy", "long term", "roadmap", "org", "stakeholder", "vp", "director"]):
        return "strategic"

    if emotion in ["distressed", "low_confidence"]:
        return "supportive"

    return "strategic"
