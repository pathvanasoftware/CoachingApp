import os
import json
from openai import AsyncOpenAI
from typing import List, Optional
from pydantic import BaseModel

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


class CoachingResponse(BaseModel):
    response: str
    quick_replies: List[str]
    suggested_actions: Optional[List[str]] = None


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
        return CoachingResponse(
            response=get_crisis_response(),
            quick_replies=["I'm safe, thanks", "I need to talk to someone", "Find professional help"],
            suggested_actions=["Contact crisis support", "Reach out to a trusted person"]
        )
    
    # Build conversation history
    messages = [{"role": "system", "content": GROW_SYSTEM_PROMPT}]
    
    if request.history:
        for msg in request.history:
            messages.append({"role": msg.role, "content": msg.content})
    
    if request.context:
        messages.append({"role": "system", "content": f"Context: {request.context}"})
    
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

            return CoachingResponse(
                response=ai_response,
                quick_replies=quick_replies,
                suggested_actions=suggested_actions
            )

        # Fallback to plain text response if model did not return valid JSON
        ai_response = raw.strip() or "I'm here to help you work through this. Could you tell me more?"
        return CoachingResponse(
            response=ai_response,
            quick_replies=generate_quick_replies(request.message, ai_response, request.context)
        )

    except Exception:
        # Fallback response if API fails
        return CoachingResponse(
            response="I'm here to help you work through this. Could you tell me more about what's on your mind?",
            quick_replies=["Let me share more", "What should I do next?", "Help me prioritize", "I'd like a concrete plan"]
        )
