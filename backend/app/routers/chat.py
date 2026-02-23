import os
import json
import asyncio
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List
from app.services.llm import CoachingRequest, CoachingResponse, get_coaching_response, generate_session_summary

router = APIRouter()


class ChatStreamRequest(BaseModel):
    sessionId: str
    message: str
    persona: str | None = None
    coachingStyle: str | None = None
    userId: str | None = "anonymous"

@router.post("/", response_model=CoachingResponse)
async def chat(request: CoachingRequest) -> CoachingResponse:
    """Handle coaching chat messages"""
    if os.getenv("REQUIRE_OPENAI_KEY", "1") == "1" and not os.getenv("OPENAI_API_KEY"):
        raise HTTPException(status_code=503, detail="OPENAI_API_KEY is required in strict mode")
    return await get_coaching_response(request)

@router.post("/quick-replies")
async def get_quick_replies(message: str, response: str = "") -> dict:
    """Get suggested quick replies for a message"""
    from app.services.llm import generate_quick_replies
    return {"quick_replies": generate_quick_replies(message, response)}


@router.post("/chat-stream")
async def chat_stream(request: ChatStreamRequest):
    """SSE stream for iOS client. First emits metadata, then token chunks."""

    if os.getenv("REQUIRE_OPENAI_KEY", "1") == "1" and not os.getenv("OPENAI_API_KEY"):
        raise HTTPException(status_code=503, detail="OPENAI_API_KEY is required in strict mode")

    coaching_req = CoachingRequest(
        message=request.message,
        context=f"session_id={request.sessionId}",
        coaching_style=request.coachingStyle,
        user_id=request.userId or "anonymous",
    )

    result = await get_coaching_response(coaching_req)

    async def event_gen():
        meta = {
            "style_used": result.style_used,
            "emotion_detected": result.emotion_detected,
            "goal_link": result.goal_link,
            "emotion_primary": result.emotion_primary,
            "emotion_scores": result.emotion_scores,
            "sentiment": result.sentiment,
            "linguistic_markers": result.linguistic_markers,
            "behavior_signals": result.behavior_signals,
            "context_triggers": result.context_triggers,
            "recommended_style_shift": result.recommended_style_shift,
            "goal_hierarchy": result.goal_hierarchy,
            "goal_anchor": result.goal_anchor,
            "progressive_skill_building": result.progressive_skill_building,
            "outcome_prediction": result.outcome_prediction,
            "quick_replies": result.quick_replies,
        }
        yield f"data: {json.dumps({'meta': meta}, ensure_ascii=False)}\n\n"

        words = (result.response or "").split(" ")
        for i, w in enumerate(words):
            token = w if i == 0 else f" {w}"
            yield f"data: {json.dumps({'token': token}, ensure_ascii=False)}\n\n"
            await asyncio.sleep(0.02)

        yield "data: [DONE]\n\n"

    return StreamingResponse(event_gen(), media_type="text/event-stream")


class SessionSummaryRequest(BaseModel):
    messages: List[dict]
    userId: str | None = "anonymous"


@router.post("/session-summary")
async def session_summary(request: SessionSummaryRequest):
    """Generate a comprehensive summary of the coaching session"""
    if os.getenv("REQUIRE_OPENAI_KEY", "1") == "1" and not os.getenv("OPENAI_API_KEY"):
        raise HTTPException(status_code=503, detail="OPENAI_API_KEY is required in strict mode")
    
    summary = await generate_session_summary(request.messages, request.userId or "anonymous")
    return summary
