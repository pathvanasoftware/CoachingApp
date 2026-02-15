import os
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


def generate_quick_replies(response: str, context: str = None) -> List[str]:
    """Generate contextual quick reply options"""
    base_replies = [
        "Tell me more about that",
        "What's my next step?",
        "Help me brainstorm options",
        "I'd like to explore this deeper"
    ]
    
    if "goal" in response.lower() or "achieve" in response.lower():
        base_replies.insert(0, "Let's define my goal")
    if "option" in response.lower() or "choice" in response.lower():
        base_replies.insert(0, "What are my options?")
    if "action" in response.lower() or "step" in response.lower():
        base_replies.insert(0, "Create an action plan")
    
    return base_replies[:4]


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
        response = await client.chat.completions.create(
            model="gpt-4",
            messages=messages,
            max_tokens=500,
            temperature=0.7
        )
        
        ai_response = response.choices[0].message.content
        
        return CoachingResponse(
            response=ai_response,
            quick_replies=generate_quick_replies(ai_response, request.context)
        )
    except Exception as e:
        # Fallback response if API fails
        return CoachingResponse(
            response="I'm here to help you work through this. Could you tell me more about what's on your mind?",
            quick_replies=["Let me share more", "What coaching approach works best?"]
        )
