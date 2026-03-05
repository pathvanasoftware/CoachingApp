"""
llm.py — thin compatibility shim
=================================
Keeps the Pydantic request/response models and re-exports the provider
availability helpers so chat.py imports don't need to change.

All actual LLM logic lives in llm_claude.py (three-model architecture).
"""

from typing import List, Optional
from pydantic import BaseModel

from app.services.llm_claude import (
    _anthropic_available,
    _openai_available,
    get_coaching_response_claude,
    generate_session_summary_claude,
    _generate_quick_replies,
    _detect_crisis as detect_crisis,
    _crisis_response as get_crisis_response,
)

# ---------------------------------------------------------------------------
# Re-export provider helpers (imported by chat.py)
# ---------------------------------------------------------------------------

# (already imported above — just make them available at module level)

# ---------------------------------------------------------------------------
# Pydantic models (kept here so chat.py imports stay unchanged)
# ---------------------------------------------------------------------------

class ChatMessage(BaseModel):
    role: str
    content: str


class CoachingRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = None
    context: Optional[str] = None
    coaching_style: Optional[str] = None
    user_id: Optional[str] = "anonymous"
    request_id: Optional[str] = None


class CoachingResponse(BaseModel):
    response: str
    quick_replies: List[str]
    suggested_actions: Optional[List[str]] = None
    style_used: Optional[str] = None
    emotion_detected: Optional[str] = None
    goal_link: Optional[str] = None
    emotion_primary: Optional[str] = None
    emotion_scores: Optional[dict] = None
    sentiment: Optional[dict] = None
    linguistic_markers: Optional[dict] = None
    behavior_signals: Optional[dict] = None
    context_triggers: Optional[dict] = None
    recommended_style_shift: Optional[str] = None
    goal_hierarchy: Optional[dict] = None
    goal_anchor: Optional[str] = None
    progressive_skill_building: Optional[dict] = None
    outcome_prediction: Optional[dict] = None
    # Three-model fields
    model_used: Optional[str] = None
    upgrade_reasons: Optional[List[str]] = None

# ---------------------------------------------------------------------------
# Public API  (called by chat.py)
# ---------------------------------------------------------------------------

async def get_coaching_response(request: CoachingRequest) -> CoachingResponse:
    """Delegate to the three-model Claude service."""
    history = [{"role": m.role, "content": m.content} for m in (request.history or [])]

    result = await get_coaching_response_claude(
        message=request.message,
        history=history,
        user_id=request.user_id or "anonymous",
        coaching_style=request.coaching_style,
        context=request.context,
    )

    return CoachingResponse(
        response=result.get("response", ""),
        quick_replies=result.get("quick_replies", []),
        suggested_actions=result.get("suggested_actions"),
        style_used=result.get("style_used"),
        emotion_detected=result.get("emotion_detected"),
        goal_link=result.get("goal_link"),
        emotion_primary=result.get("emotion_primary"),
        emotion_scores=result.get("emotion_scores"),
        sentiment=result.get("sentiment"),
        linguistic_markers=result.get("linguistic_markers"),
        behavior_signals=result.get("behavior_signals"),
        context_triggers=result.get("context_triggers"),
        recommended_style_shift=result.get("recommended_style_shift"),
        goal_hierarchy=result.get("goal_hierarchy"),
        goal_anchor=result.get("goal_anchor"),
        progressive_skill_building=result.get("progressive_skill_building"),
        outcome_prediction=result.get("outcome_prediction"),
        model_used=result.get("model_used"),
        upgrade_reasons=result.get("upgrade_reasons"),
    )


async def generate_session_summary(messages: List[dict], user_id: str = "anonymous") -> dict:
    """Delegate to the Claude summary function."""
    return await generate_session_summary_claude(messages, user_id)


def generate_quick_replies(user_message: str, ai_response: str, context: Optional[str] = None) -> List[str]:
    """Rule-based quick reply generation (no LLM call)."""
    return _generate_quick_replies(user_message, ai_response, context or "")


def _safe_parse_structured_output(raw_text: str):
    """Compatibility shim — parse JSON dict from raw model output."""
    if not raw_text:
        return None
    import json as _json
    try:
        parsed = _json.loads(raw_text)
        if isinstance(parsed, dict):
            return parsed
    except Exception:
        pass
    start, end = raw_text.find("{"), raw_text.rfind("}") + 1
    if start != -1 and end > start:
        try:
            parsed = _json.loads(raw_text[start:end])
            if isinstance(parsed, dict):
                return parsed
        except Exception:
            pass
    return None


def _clean_response_text(raw_text: str) -> str:
    """Compatibility shim — strips JSON wrappers from plain text responses."""
    txt = (raw_text or "").strip()
    if not txt:
        return ""
    import json as _json
    for _ in range(3):
        try:
            start, end = txt.find("{"), txt.rfind("}") + 1
            if start != -1 and end > start:
                parsed = _json.loads(txt[start:end])
                if isinstance(parsed.get("response"), str):
                    txt = parsed["response"].strip()
                    continue
        except Exception:
            pass
        break
    return txt
