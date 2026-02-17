import os
import json
from openai import AsyncOpenAI
from typing import List, Optional
from pydantic import BaseModel
from app.services.style_router import route_style, STYLE_PROMPTS
from app.services.emotion_analyzer import detect_emotion
from app.services.context_engine import build_context_packet, infer_goal_link
from app.services.memory_store import load_profile, update_profile_from_turn, save_profile
from app.services.emotion_engine import analyze_text_emotion, infer_context_triggers
from app.services.behavior_tracker import update_behavior_signals, style_preference_shift

def get_openai_client() -> AsyncOpenAI:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY not configured")
    return AsyncOpenAI(api_key=api_key)

GROW_SYSTEM_PROMPT = """You are an expert Career & Executive Coach using the GROW model.

**GROW Framework:**
1. **Goal**: What does the coachee want to achieve?
2. **Reality**: What is the current situation?
3. **Options**: What choices do they have?
4. **Will/Way Forward**: What specific actions will they take?

**Coaching Principles:**
- Ask powerful questions, don't just give answers
- Help coachees discover their own solutions
- Be supportive but challenge assumptions
- Focus on actionable outcomes
- Celebrate progress and insights

**Crisis Protocol:**
If someone expresses thoughts of self-harm, suicide, or severe distress:
1. Express genuine concern
2. Provide crisis resources immediately
3. Recommend professional help
4. Do not attempt to provide therapy

Crisis Resources:
- National Suicide Prevention Lifeline: 988 (US)
- Crisis Text Line: Text HOME to 741741
- International Association for Suicide Prevention: https://www.iasp.info/resources/Crisis_Centres/

Always maintain a warm, professional, and supportive tone. Keep responses concise but meaningful (2-4 paragraphs max unless exploring deeply)."""


class ChatMessage(BaseModel):
    role: str
    content: str


class CoachingRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessage]] = None
    context: Optional[str] = None
    coaching_style: Optional[str] = None
    user_id: Optional[str] = "anonymous"


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


def _safe_parse_structured_output(raw_text: str) -> Optional[dict]:
    """Try to parse model output as JSON dict."""
    if not raw_text:
        return None

    # Direct JSON parse
    try:
        parsed = json.loads(raw_text)
        if isinstance(parsed, dict):
            return parsed
    except Exception:
        pass

    # Try extracting first JSON object block
    start = raw_text.find("{")
    end = raw_text.rfind("}")
    if start != -1 and end != -1 and end > start:
        try:
            parsed = json.loads(raw_text[start:end + 1])
            if isinstance(parsed, dict):
                return parsed
        except Exception:
            return None

    return None


def detect_crisis(message: str) -> bool:
    """Detect potential crisis indicators"""
    crisis_keywords = [
        "suicide", "kill myself", "end my life", "want to die",
        "hurt myself", "no reason to live", "better off dead"
    ]
    message_lower = message.lower()
    return any(keyword in message_lower for keyword in crisis_keywords)


def get_crisis_response() -> str:
    """Return crisis resources"""
    return """I'm concerned about what you're sharing. Your wellbeing matters, and there are people who can help right now:

🆘 **Immediate Support:**
- **National Suicide Prevention Lifeline**: Call or text **988** (US)
- **Crisis Text Line**: Text **HOME** to **741741**
- **International resources**: https://findahelpline.com

These services are free, confidential, and available 24/7. You don't have to face this alone.

Would you like to talk about what's going on? I'm here to listen, and I can also help you find professional support in your area."""


def generate_quick_replies(user_message: str, ai_response: str, context: str = None) -> List[str]:
    """Generate contextual quick reply options based on user's latest answer + AI response."""
    user = (user_message or "").lower()
    coach = (ai_response or "").lower()

    # Always keep one generic exploration option
    options: List[str] = ["Tell me more"]

    # User-intent driven options (primary signal)
    if any(k in user for k in ["promotion", "raise", "salary", "compensation"]):
        options += ["How do I negotiate this?", "What proof should I prepare?"]
    if any(k in user for k in ["switch", "change career", "transition", "new role"]):
        options += ["How do I de-risk this move?", "What should my 30-60-90 day plan be?"]
    if any(k in user for k in ["team", "manager", "leadership", "conflict", "boss"]):
        options += ["How should I handle this conversation?", "Give me a script I can use"]
    if any(k in user for k in ["stuck", "overwhelmed", "burnout", "stress", "anxious"]):
        options += ["Help me prioritize next steps", "What's the smallest next action?"]

    # Coach-response driven options (secondary signal)
    if any(k in coach for k in ["goal", "achieve", "outcome"]):
        options.append("Let's define the exact goal")
    if any(k in coach for k in ["option", "choice", "alternative"]):
        options.append("Show me 3 options")
    if any(k in coach for k in ["action", "step", "plan"]):
        options.append("Turn this into an action plan")

    # Fallbacks if intent signals are weak
    if len(options) < 4:
        options += [
            "What should I do next?",
            "Help me brainstorm options",
            "I'd like to explore this deeper"
        ]

    # De-duplicate while preserving order
    seen = set()
    deduped = []
    for opt in options:
        if opt not in seen:
            seen.add(opt)
            deduped.append(opt)

    return deduped[:4]


async def get_coaching_response(request: CoachingRequest) -> CoachingResponse:
    """Get AI coaching response using GPT-4"""
    
    # Check for crisis indicators
    if detect_crisis(request.message):
        profile = update_profile_from_turn(
            request.user_id or "anonymous",
            request.message,
            "wellbeing_first",
            style_used="supportive",
            emotion_primary="high_stress",
            context_triggers=context_triggers,
        )
        profile = update_behavior_signals(profile, style_used="supportive", goal_link="wellbeing_first")
        save_profile(request.user_id or "anonymous", profile)
        return CoachingResponse(
            response=get_crisis_response(),
            quick_replies=["I'm safe, thanks", "I need to talk to someone", "Find professional help"],
            suggested_actions=["Contact crisis support", "Reach out to a trusted person"],
            style_used="supportive",
            emotion_detected="distressed",
            goal_link="wellbeing_first",
            emotion_primary="high_stress",
            emotion_scores=ei.scores,
            sentiment=ei.sentiment,
            linguistic_markers=ei.linguistic_markers,
            behavior_signals={
                "style_preference_shift": style_preference_shift(profile),
                "interaction_frequency_hint": "tracked",
            },
            context_triggers=context_triggers,
            recommended_style_shift="supportive"
        )
    
    # Build context + style orchestration
    emotion = detect_emotion(request.message)
    style_used = route_style(request.message, request.coaching_style, emotion)
    goal_link = infer_goal_link(request.message)

    ei = analyze_text_emotion(request.message)
    context_triggers = infer_context_triggers(request.message)

    history_dicts = [{"role": m.role, "content": m.content} for m in (request.history or [])]
    context_packet = build_context_packet(request.message, history_dicts, request.context)
    profile = load_profile(request.user_id or "anonymous")

    messages = [
        {"role": "system", "content": GROW_SYSTEM_PROMPT},
        {"role": "system", "content": f"Coaching style to use this turn: {style_used}. {STYLE_PROMPTS[style_used]}"},
        {"role": "system", "content": f"Emotion detected: {emotion}. Goal alignment tag: {goal_link}."},
        {"role": "system", "content": f"Persistent profile memory: {json.dumps(profile, ensure_ascii=False)}"},
        {"role": "system", "content": "Session orchestration: structure each turn as (1) brief acknowledgment, (2) core coaching move, (3) one concrete next step."},
        {"role": "system", "content": context_packet},
    ]

    if request.history:
        for msg in request.history:
            messages.append({"role": msg.role, "content": msg.content})

    messages.append({"role": "user", "content": request.message})
    
    try:
        client = get_openai_client()

        # Ask model to generate BOTH coaching response + contextual quick-reply options.
        structured_messages = messages + [{
            "role": "system",
            "content": (
                "Return ONLY valid JSON with this shape: "
                "{\"response\": string, \"quick_replies\": [string, string, string, string], \"suggested_actions\": [string]}. "
                "quick_replies must be concise (3-8 words), user-selectable, and tailored to the user's latest message. "
                "No markdown, no extra text."
            )
        }]

        response = await client.chat.completions.create(
            model="gpt-4",
            messages=structured_messages,
            max_tokens=600,
            temperature=0.7
        )

        raw = response.choices[0].message.content or ""
        parsed = _safe_parse_structured_output(raw)

        if parsed and isinstance(parsed.get("response"), str):
            ai_response = parsed.get("response", "").strip()
            quick_replies = parsed.get("quick_replies", [])
            suggested_actions = parsed.get("suggested_actions", None)

            if not isinstance(quick_replies, list):
                quick_replies = []

            quick_replies = [str(x).strip() for x in quick_replies if str(x).strip()]
            if len(quick_replies) < 2:
                quick_replies = generate_quick_replies(request.message, ai_response, request.context)
            else:
                quick_replies = quick_replies[:4]

            if isinstance(suggested_actions, list):
                suggested_actions = [str(x).strip() for x in suggested_actions if str(x).strip()][:5]
            else:
                suggested_actions = None

            profile = update_profile_from_turn(
                request.user_id or "anonymous",
                request.message,
                goal_link,
                style_used=style_used,
                emotion_primary=ei.primary,
                context_triggers=context_triggers,
            )
            profile = update_behavior_signals(profile, style_used=style_used, goal_link=goal_link)
            save_profile(request.user_id or "anonymous", profile)
            return CoachingResponse(
                response=ai_response,
                quick_replies=quick_replies,
                suggested_actions=suggested_actions,
                style_used=style_used,
                emotion_detected=emotion,
                goal_link=goal_link,
                emotion_primary=ei.primary,
                emotion_scores=ei.scores,
                sentiment=ei.sentiment,
                linguistic_markers=ei.linguistic_markers,
                behavior_signals={
                    "style_preference_shift": style_preference_shift(profile),
                    "session_event_count": len(profile.get("session_events", [])),
                },
                context_triggers=context_triggers,
                recommended_style_shift=style_preference_shift(profile),
            )

        # Fallback to plain text response if model did not return valid JSON
        ai_response = raw.strip() or "I'm here to help you work through this. Could you tell me more?"
        profile = update_profile_from_turn(
            request.user_id or "anonymous",
            request.message,
            goal_link,
            style_used=style_used,
            emotion_primary=ei.primary,
            context_triggers=context_triggers,
        )
        profile = update_behavior_signals(profile, style_used=style_used, goal_link=goal_link)
        save_profile(request.user_id or "anonymous", profile)
        return CoachingResponse(
            response=ai_response,
            quick_replies=generate_quick_replies(request.message, ai_response, request.context),
            style_used=style_used,
            emotion_detected=emotion,
            goal_link=goal_link,
            emotion_primary=ei.primary,
            emotion_scores=ei.scores,
            sentiment=ei.sentiment,
            linguistic_markers=ei.linguistic_markers,
            behavior_signals={
                "style_preference_shift": style_preference_shift(profile),
                "session_event_count": len(profile.get("session_events", [])),
            },
            context_triggers=context_triggers,
            recommended_style_shift=style_preference_shift(profile),
        )

    except Exception:
        # Fallback response if API fails
        fallback_goal = goal_link if 'goal_link' in locals() else "professional_growth"
        fallback_style = style_used if 'style_used' in locals() else "strategic"
        fallback_emotion = emotion if 'emotion' in locals() else "neutral"

        profile = update_profile_from_turn(
            request.user_id or "anonymous",
            request.message,
            fallback_goal,
            style_used=fallback_style,
            emotion_primary=(ei.primary if 'ei' in locals() else "neutral"),
            context_triggers=(context_triggers if 'context_triggers' in locals() else {}),
        )
        profile = update_behavior_signals(profile, style_used=fallback_style, goal_link=fallback_goal)
        save_profile(request.user_id or "anonymous", profile)

        return CoachingResponse(
            response="I'm here to help you work through this. Could you tell me more about what's on your mind?",
            quick_replies=["Let me share more", "What should I do next?", "Help me prioritize", "I'd like a concrete plan"],
            style_used=fallback_style,
            emotion_detected=fallback_emotion,
            goal_link=fallback_goal,
            emotion_primary=(ei.primary if 'ei' in locals() else "neutral"),
            emotion_scores=(ei.scores if 'ei' in locals() else {"neutral": 1.0}),
            sentiment=(ei.sentiment if 'ei' in locals() else {"positive": 0.2, "negative": 0.2, "neutral": 0.6}),
            linguistic_markers=(ei.linguistic_markers if 'ei' in locals() else {}),
            behavior_signals={
                "style_preference_shift": style_preference_shift(profile),
                "session_event_count": len(profile.get("session_events", [])),
            },
            context_triggers=(context_triggers if 'context_triggers' in locals() else {}),
            recommended_style_shift=style_preference_shift(profile),
        )
