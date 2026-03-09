from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel

from app.routers.auth import get_current_user
from app.services.llm import (
    CoachingRequest,
    _anthropic_available,
    _openai_available,
    generate_session_summary,
    get_coaching_response,
)
from app.services.sessions import session_service


router = APIRouter()


class StartSessionRequest(BaseModel):
    user_id: str
    persona: str
    session_type: str
    input_mode: str


class EndSessionRequest(BaseModel):
    session_id: str


class SendMessageRequest(BaseModel):
    session_id: str
    content: str
    role: str = "user"


def _require_llm_or_503():
    if not _anthropic_available() and not _openai_available():
        raise HTTPException(
            status_code=503,
            detail="No LLM API key configured. Set ANTHROPIC_API_KEY (preferred) or OPENAI_API_KEY.",
        )


def _assistant_diagnostics_from_result(result) -> Dict[str, Any]:
    goal_hierarchy = getattr(result, "goal_hierarchy", None)
    progressive = getattr(result, "progressive_skill_building", None)
    outcome = getattr(result, "outcome_prediction", None)

    return {
        "style_used": getattr(result, "style_used", "") or "",
        "emotion_detected": getattr(result, "emotion_detected", "") or "",
        "goal_link": getattr(result, "goal_link", "") or "",
        "goal_anchor": getattr(result, "goal_anchor", None),
        "goal_hierarchy_summary": goal_hierarchy if isinstance(goal_hierarchy, str) else None,
        "progressive_skill_summary": progressive if isinstance(progressive, str) else None,
        "outcome_prediction_summary": outcome if isinstance(outcome, str) else None,
        "risk_level": None,
        "recommended_style_shift": getattr(result, "recommended_style_shift", None),
    }


@router.post("/sessions")
async def start_session(request: StartSessionRequest, user_id: str = Depends(get_current_user)):
    if request.user_id != user_id:
        raise HTTPException(status_code=403, detail="Cannot start a session for a different user")

    return session_service.create_session(
        user_id=user_id,
        persona=request.persona,
        session_type=request.session_type,
        input_mode=request.input_mode,
    )


@router.get("/sessions")
async def list_sessions(user_id: str = Depends(get_current_user)):
    return session_service.list_sessions(user_id)


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_session(session_id: str, user_id: str = Depends(get_current_user)):
    deleted = session_service.delete_session(session_id, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Session not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/sessions/{session_id}/end")
async def end_session(session_id: str, request: EndSessionRequest, user_id: str = Depends(get_current_user)):
    if request.session_id != session_id:
        raise HTTPException(status_code=400, detail="Session ID mismatch")

    messages = session_service.list_messages(session_id, user_id)
    summary_text: Optional[str] = None
    summary_messages = [
        {"role": message["role"], "content": message["content"]}
        for message in messages
        if message.get("role") in {"user", "assistant"} and message.get("content")
    ]

    if summary_messages and (_anthropic_available() or _openai_available()):
        try:
            summary_payload = await generate_session_summary(summary_messages, user_id)
            generated_summary = (summary_payload or {}).get("summary", "").strip()
            if generated_summary:
                summary_text = generated_summary
        except Exception:
            summary_text = None

    ended = session_service.end_session(session_id, user_id, summary=summary_text)
    if not ended:
        raise HTTPException(status_code=404, detail="Session not found")
    return ended


@router.get("/sessions/{session_id}/messages")
async def get_messages(session_id: str, user_id: str = Depends(get_current_user)):
    session = session_service.get_session(session_id, user_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session_service.list_messages(session_id, user_id)


@router.post("/sessions/{session_id}/messages")
async def send_message(session_id: str, request: SendMessageRequest, user_id: str = Depends(get_current_user)):
    if request.session_id != session_id:
        raise HTTPException(status_code=400, detail="Session ID mismatch")

    session = session_service.get_session(session_id, user_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if session.get("ended_at"):
        raise HTTPException(status_code=409, detail="Session already ended")

    _require_llm_or_503()

    coaching_request = CoachingRequest(
        message=request.content,
        context=f"session_id={session_id}",
        user_id=user_id,
    )
    result = await get_coaching_response(coaching_request)

    session_service.record_turn(
        session_id=session_id,
        user_content=request.content,
        assistant_content=result.response,
        assistant_diagnostics=_assistant_diagnostics_from_result(result),
    )

    messages = session_service.list_messages(session_id, user_id)
    if not messages:
        raise HTTPException(status_code=500, detail="Failed to persist message")
    return messages[-1]
