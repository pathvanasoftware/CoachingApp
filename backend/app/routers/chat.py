import json
import asyncio
import hashlib
import os
import random
import time
import uuid
from typing import Dict, List, Optional, Union

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel

from app.services.llm import CoachingRequest, CoachingResponse, get_coaching_response, generate_session_summary, _anthropic_available, _openai_available
from app.services.cache import build_cache_backend

router = APIRouter()
response_cache = build_cache_backend()

IDEMP_TTL_SECONDS = int(os.getenv("IDEMP_TTL_SECONDS", "1200"))
LOCK_TTL_SECONDS = int(os.getenv("LOCK_TTL_SECONDS", "120"))
FOLLOWER_WAIT_SECONDS_CHAT = float(os.getenv("FOLLOWER_WAIT_SECONDS_CHAT", "12"))
FOLLOWER_WAIT_SECONDS_STREAM = float(os.getenv("FOLLOWER_WAIT_SECONDS_STREAM", "120"))
FOLLOWER_POLL_MIN_SECONDS = float(os.getenv("FOLLOWER_POLL_MIN_SECONDS", "0.25"))
FOLLOWER_POLL_MAX_SECONDS = float(os.getenv("FOLLOWER_POLL_MAX_SECONDS", "0.50"))
FOLLOWER_RETRY_AFTER_MS = int(os.getenv("FOLLOWER_RETRY_AFTER_MS", "750"))
SSE_KEEPALIVE_SECONDS = float(os.getenv("SSE_KEEPALIVE_SECONDS", "10"))


def _require_llm_or_503():
    """Raise 503 if no LLM API key is configured."""
    if not _anthropic_available() and not _openai_available():
        raise HTTPException(
            status_code=503,
            detail="No LLM API key configured. Set ANTHROPIC_API_KEY (preferred) or OPENAI_API_KEY."
        )


class ChatStreamRequest(BaseModel):
    sessionId: str
    message: str
    persona: Optional[str] = None
    coachingStyle: Optional[str] = None
    userId: Optional[str] = "anonymous"
    requestId: Optional[str] = None


class ProcessingResponse(BaseModel):
    status: str
    request_id: str
    retry_after_ms: int
    poll_url: Optional[str] = None


def _idem_key(user_id: str, request_id: str) -> str:
    return f"idem:{user_id}:{request_id}"


def _idem_lock_key(user_id: str, request_id: str) -> str:
    return f"idemlock:{user_id}:{request_id}"


def _summary_cache_key(user_id: str, messages: List[dict]) -> str:
    canonical = [
        {
            "role": str(item.get("role", "")),
            "content": str(item.get("content", "")),
        }
        for item in (messages or [])
        if isinstance(item, dict)
    ]
    raw = json.dumps(canonical, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()
    return f"summary:{user_id}:{digest}"


def _chat_signature(request: CoachingRequest) -> str:
    history_payload = [
        {
            "role": str(item.role),
            "content": str(item.content),
        }
        for item in (request.history or [])
    ]
    payload = {
        "message": request.message,
        "history": history_payload,
        "context": request.context,
        "coaching_style": request.coaching_style,
        "user_id": request.user_id or "anonymous",
    }
    raw = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _stream_signature(request: ChatStreamRequest) -> str:
    payload = {
        "session_id": request.sessionId,
        "message": request.message,
        "persona": request.persona,
        "coaching_style": request.coachingStyle,
        "user_id": request.userId or "anonymous",
    }
    raw = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _response_payload(result: CoachingResponse) -> Dict:
    return result.model_dump()


def _response_from_payload(payload: Dict) -> CoachingResponse:
    return CoachingResponse(**payload)


def _meta_from_result(result: CoachingResponse) -> Dict:
    return {
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
        "model_used": result.model_used,
        "upgrade_reasons": result.upgrade_reasons,
    }


def _cache_record(result: CoachingResponse, signature: str, request_id: str) -> Dict:
    behavior = result.behavior_signals or {}
    return {
        "request_id": request_id,
        "signature": signature,
        "response": _response_payload(result),
        "pre_state_rev": behavior.get("pre_state_rev"),
        "post_state_rev": behavior.get("post_state_rev"),
        "cached_at_ms": int(time.time() * 1000),
    }


def _require_matching_signature(record: Dict, signature: str) -> None:
    cached_sig = record.get("signature")
    if cached_sig and cached_sig != signature:
        raise HTTPException(status_code=409, detail="request_id already used for a different payload")


async def _wait_for_record(cache_key: str, signature: str, wait_seconds: float) -> Optional[Dict]:
    deadline = time.monotonic() + max(0.0, wait_seconds)
    while time.monotonic() < deadline:
        record = await response_cache.get_json(cache_key)
        if record:
            _require_matching_signature(record, signature)
            return record
        await asyncio.sleep(random.uniform(FOLLOWER_POLL_MIN_SECONDS, FOLLOWER_POLL_MAX_SECONDS))
    return None


async def _stream_result(result: CoachingResponse):
    meta = _meta_from_result(result)
    yield f"data: {json.dumps({'meta': meta}, ensure_ascii=False)}\n\n"

    words = (result.response or "").split(" ")
    for i, word in enumerate(words):
        token = word if i == 0 else f" {word}"
        yield f"data: {json.dumps({'token': token}, ensure_ascii=False)}\n\n"
        await asyncio.sleep(0.02)

    yield "data: [DONE]\n\n"


def _processing_payload(request_id: str, *, poll_url: Optional[str]) -> Dict:
    body = ProcessingResponse(
        status="processing",
        request_id=request_id,
        retry_after_ms=FOLLOWER_RETRY_AFTER_MS,
        poll_url=poll_url,
    )
    return body.model_dump()


@router.post("/", response_model=Union[CoachingResponse, ProcessingResponse])
async def chat(request: CoachingRequest):
    """Handle coaching chat messages"""
    _require_llm_or_503()

    user_id = request.user_id or "anonymous"
    request_id = (request.request_id or "").strip()

    if not request_id:
        return await get_coaching_response(request)

    signature = _chat_signature(request)
    cache_key = _idem_key(user_id, request_id)
    lock_key = _idem_lock_key(user_id, request_id)

    cached = await response_cache.get_json(cache_key)
    if cached:
        _require_matching_signature(cached, signature)
        return _response_from_payload(cached.get("response") or {})

    lock_owner = str(uuid.uuid4())
    got_lock = await response_cache.acquire_lock(lock_key, lock_owner, LOCK_TTL_SECONDS)
    if got_lock:
        try:
            result = await get_coaching_response(request)
            await response_cache.set_json(
                cache_key,
                _cache_record(result, signature, request_id),
                IDEMP_TTL_SECONDS,
            )
            return result
        finally:
            await response_cache.release_lock(lock_key, lock_owner)

    waited = await _wait_for_record(cache_key, signature, FOLLOWER_WAIT_SECONDS_CHAT)
    if waited:
        return _response_from_payload(waited.get("response") or {})

    payload = _processing_payload(request_id, poll_url=f"/api/chat/result?user_id={user_id}&request_id={request_id}")
    return JSONResponse(
        status_code=202,
        content=payload,
        headers={"Retry-After": str(max(1, FOLLOWER_RETRY_AFTER_MS // 1000))},
    )

@router.post("/quick-replies")
async def get_quick_replies(message: str, response: str = "") -> dict:
    """Get suggested quick replies for a message"""
    from app.services.llm import generate_quick_replies
    return {"quick_replies": generate_quick_replies(message, response)}


@router.post("/chat-stream")
async def chat_stream(request: ChatStreamRequest):
    """SSE stream for iOS client. First emits metadata, then token chunks."""

    _require_llm_or_503()

    user_id = request.userId or "anonymous"
    request_id = (request.requestId or "").strip()

    async def stream_waiting_and_replay(cache_key: str, signature: str, req_id: str):
        deadline = time.monotonic() + max(0.0, FOLLOWER_WAIT_SECONDS_STREAM)
        last_keepalive_at = 0.0

        while time.monotonic() < deadline:
            record = await response_cache.get_json(cache_key)
            if record:
                _require_matching_signature(record, signature)
                cached_result = _response_from_payload(record.get("response") or {})
                async for chunk in _stream_result(cached_result):
                    yield chunk
                return

            now = time.monotonic()
            if now - last_keepalive_at >= SSE_KEEPALIVE_SECONDS:
                yield ": keepalive\n\n"
                last_keepalive_at = now

            await asyncio.sleep(random.uniform(FOLLOWER_POLL_MIN_SECONDS, FOLLOWER_POLL_MAX_SECONDS))

        timeout_payload = {
            "error": "processing_timeout",
            "request_id": req_id,
            "retry_after_ms": FOLLOWER_RETRY_AFTER_MS,
        }
        yield f"data: {json.dumps({'meta': timeout_payload}, ensure_ascii=False)}\n\n"
        yield "data: [DONE]\n\n"

    coaching_req = CoachingRequest(
        message=request.message,
        context=f"session_id={request.sessionId}",
        coaching_style=request.coachingStyle,
        user_id=user_id,
        request_id=request_id or None,
    )

    if not request_id:
        result = await get_coaching_response(coaching_req)
        return StreamingResponse(_stream_result(result), media_type="text/event-stream")

    signature = _stream_signature(request)
    cache_key = _idem_key(user_id, request_id)
    lock_key = _idem_lock_key(user_id, request_id)

    cached = await response_cache.get_json(cache_key)
    if cached:
        _require_matching_signature(cached, signature)
        result = _response_from_payload(cached.get("response") or {})
        return StreamingResponse(_stream_result(result), media_type="text/event-stream")

    lock_owner = str(uuid.uuid4())
    got_lock = await response_cache.acquire_lock(lock_key, lock_owner, LOCK_TTL_SECONDS)
    if not got_lock:
        return StreamingResponse(
            stream_waiting_and_replay(cache_key, signature, request_id),
            media_type="text/event-stream",
        )

    try:
        result = await get_coaching_response(coaching_req)
        await response_cache.set_json(
            cache_key,
            _cache_record(result, signature, request_id),
            IDEMP_TTL_SECONDS,
        )
    finally:
        await response_cache.release_lock(lock_key, lock_owner)

    return StreamingResponse(_stream_result(result), media_type="text/event-stream")


@router.get("/result", response_model=Union[CoachingResponse, ProcessingResponse])
async def chat_result(
    request_id: str = Query(..., min_length=1),
    user_id: str = Query("anonymous", min_length=1),
):
    cache_key = _idem_key(user_id, request_id)
    record = await response_cache.get_json(cache_key)
    if not record:
        payload = _processing_payload(request_id, poll_url=f"/api/chat/result?user_id={user_id}&request_id={request_id}")
        return JSONResponse(
            status_code=202,
            content=payload,
            headers={"Retry-After": str(max(1, FOLLOWER_RETRY_AFTER_MS // 1000))},
        )
    return _response_from_payload(record.get("response") or {})


class SessionSummaryRequest(BaseModel):
    messages: List[dict]
    userId: Optional[str] = "anonymous"


@router.post("/session-summary")
async def session_summary(request: SessionSummaryRequest):
    """Generate a comprehensive summary of the coaching session"""
    _require_llm_or_503()

    user_id = request.userId or "anonymous"
    cache_key = _summary_cache_key(user_id, request.messages)
    cached = await response_cache.get_json(cache_key)
    if cached:
        return cached

    summary = await generate_session_summary(request.messages, user_id)
    if isinstance(summary, dict):
        await response_cache.set_json(cache_key, summary, int(os.getenv("SUMMARY_CACHE_TTL_SECONDS", "604800")))
    return summary
