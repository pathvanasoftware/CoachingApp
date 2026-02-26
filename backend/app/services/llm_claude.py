"""
Claude LLM Service with Dual-Model Architecture

Default: Claude Sonnet 4.6 (cost-efficient, excellent coaching style)
Upgrade: Claude Opus 4.6 (complex decisions, deep reflection, long context)
"""

import os
import json
from typing import List, Dict, Optional, Tuple
from anthropic import AsyncAnthropic
from app.services.style_router import route_style
from app.services.emotion_analyzer import detect_emotion
from app.services.memory_store import load_profile, update_profile_from_turn, save_profile
from app.services.emotion_engine import analyze_text_emotion, infer_context_triggers
from app.services.behavior_tracker import update_behavior_signals, style_preference_shift
from app.services.goal_architecture import infer_goal_hierarchy, build_goal_anchor
from app.prompts.proprietary_frameworks import get_framework_for_context

# Model IDs
CLAUDE_SONNET_4_6 = "claude-sonnet-4-6-20250514"  # Default (90% of conversations)
CLAUDE_OPUS_4_6 = "claude-opus-4-6-20250514"     # Upgrade (10% of conversations)

# GROW Coaching System Prompt
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
If someone explicitly expresses thoughts of self-harm or suicide:
1. Express genuine concern
2. Provide crisis resources immediately
3. Recommend professional help
4. Do not attempt to provide therapy

**Coaching-Appropriate Topics:**
Career stress, burnout, overwhelm, work-life balance, job dissatisfaction, and professional challenges are all appropriate for coaching. These are NOT crises. Coach them normally with empathy and strategic guidance.

Crisis Resources (only share for explicit self-harm/suicide statements):
- National Suicide Prevention Lifeline: 988 (US)
- Crisis Text Line: Text HOME to 741741
- International Association for Suicide Prevention: https://www.iasp.info/resources/Crisis_Centres/

Always maintain a warm, professional, and supportive tone. Keep responses concise but meaningful (2-4 paragraphs max unless exploring deeply)."""


def get_anthropic_client() -> AsyncAnthropic:
    """Get Anthropic API client"""
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY not configured")
    return AsyncAnthropic(api_key=api_key)


def select_model(
    conversation_history: List[Dict],
    current_message: str,
    user_context: Optional[Dict] = None
) -> Tuple[str, List[str]]:
    """
    Auto-select Claude model based on context
    
    Returns:
        Tuple of (model_id, list_of_upgrade_reasons)
    """
    
    # Default to Sonnet
    model = CLAUDE_SONNET_4_6
    upgrade_signals = []
    
    if user_context is None:
        user_context = {}
    
    # 1. Conversation length (>40 turns)
    if len(conversation_history) > 40:
        upgrade_signals.append("long_context")
    
    # 2. Complex decision keywords
    complex_keywords = [
        "job offer", "multiple offers", "should i choose",
        "trade-off", "权衡", "多个选择", "难以决定"
    ]
    if any(kw in current_message.lower() for kw in complex_keywords):
        upgrade_signals.append("complex_decision")
    
    # 3. Deep reflection keywords
    reflection_keywords = [
        "i don't know why", "self-sabotage", "pattern",
        "为什么我总是", "自我破坏", "深层原因"
    ]
    if any(kw in current_message.lower() for kw in reflection_keywords):
        upgrade_signals.append("deep_reflection")
    
    # 4. Strategic planning
    strategic_keywords = [
        "career pivot", "5 year plan", "long-term",
        "职业转型", "长期规划", "战略"
    ]
    if any(kw in current_message.lower() for kw in strategic_keywords):
        upgrade_signals.append("strategic_planning")
    
    # 5. Escalation risk detected
    if user_context.get("escalation_risk") in ["medium", "high"]:
        upgrade_signals.append("escalation_prep")
    
    # Upgrade if any signals detected
    if upgrade_signals:
        model = CLAUDE_OPUS_4_6
    
    return model, upgrade_signals


async def get_coaching_response(
    message: str,
    history: Optional[List[Dict]] = None,
    user_id: str = "anonymous",
    coaching_style: Optional[str] = None,
    context: Optional[str] = None
) -> Dict:
    """
    Generate coaching response using Claude
    
    Args:
        message: User's current message
        history: Conversation history
        user_id: User identifier
        coaching_style: Optional style override
        context: Additional context
        
    Returns:
        Dict with response, metadata, quick replies
    """
    
    if history is None:
        history = []
    
    try:
        client = get_anthropic_client()
        
        # Load user profile
        profile = load_profile(user_id) or {}
        
        # Detect emotion
        emotion = detect_emotion(message)
        
        # Route coaching style
        style_used = coaching_style or route_style(message, emotion, history)
        
        # Get proprietary framework
        framework = get_framework_for_context(message, history)
        
        # Build user context for model selection
        user_context = {
            "user_id": user_id,
            "profile": profile,
            "escalation_risk": detect_escalation_risk(message, history),
        }
        
        # Auto-select model
        model, upgrade_reasons = select_model(history, message, user_context)
        
        # Build messages for Claude
        messages = []
        for turn in history[-10:]:  # Last 10 turns
            messages.append({
                "role": turn.get("role", "user"),
                "content": turn.get("content", "")
            })
        
        # Add current message
        messages.append({"role": "user", "content": message})
        
        # Build system prompt with style and framework
        system_prompt = f"{GROW_SYSTEM_PROMPT}\n\n"
        system_prompt += f"Coaching Style: {style_used}\n\n"
        if framework:
            system_prompt += f"Use this framework when appropriate:\n{framework}\n\n"
        
        # Add user context
        if profile:
            system_prompt += f"User Context:\n"
            system_prompt += f"- Role: {profile.get('role', 'Unknown')}\n"
            system_prompt += f"- Experience: {profile.get('experience_years', 0)} years\n"
            if profile.get('active_goal'):
                system_prompt += f"- Active Goal: {profile['active_goal']}\n"
        
        # Call Claude API
        response = await client.messages.create(
            model=model,
            max_tokens=800,
            system=system_prompt,
            messages=messages,
        )
        
        # Extract response text
        response_text = response.content[0].text
        
        # Generate quick replies
        quick_replies = generate_quick_replies(response_text, message, emotion)
        
        # Update user profile
        update_profile_from_turn(user_id, message, response_text, emotion)
        
        # Analyze emotion signals
        emotion_data = analyze_text_emotion(message)
        
        # Update behavior signals
        behavior = update_behavior_signals(user_id, style_used, None)
        
        # Build goal context
        goal_link = None
        if profile.get('active_goal'):
            goal_link = build_goal_anchor(profile['active_goal'], message)
        
        return {
            "response": response_text,
            "quick_replies": quick_replies,
            "style_used": style_used,
            "emotion_detected": emotion,
            "goal_link": goal_link,
            "model_used": model,
            "upgrade_reasons": upgrade_reasons,
            "emotion_primary": emotion_data.get("primary_emotion"),
            "emotion_scores": emotion_data.get("emotion_scores"),
            "behavior_signals": behavior,
        }
        
    except Exception as e:
        # Fallback response
        return {
            "response": f"I apologize, but I encountered an error. Please try again. Error: {str(e)}",
            "quick_replies": ["Tell me more", "Let's try again"],
            "style_used": "supportive",
            "emotion_detected": "neutral",
            "model_used": CLAUDE_SONNET_4_6,
            "error": str(e),
        }


def detect_escalation_risk(message: str, history: List[Dict]) -> str:
    """
    Detect if conversation might need escalation
    
    Returns:
        "none", "low", "medium", "high"
    """
    
    # Crisis keywords
    crisis_keywords = [
        "kill myself", "suicide", "want to die",
        "自杀", "想死"
    ]
    if any(kw in message.lower() for kw in crisis_keywords):
        return "high"
    
    # Complex situation keywords
    complex_keywords = [
        "legal", "lawsuit", "hr investigation",
        "法律", "起诉", "调查"
    ]
    if any(kw in message.lower() for kw in complex_keywords):
        return "medium"
    
    # Repeated loops (same topic 3+ times)
    if len(history) >= 6:
        recent_topics = [turn.get("content", "").lower() for turn in history[-6:]]
        # Simple check - if user mentions same thing multiple times
        # In production, use topic clustering
        if len(recent_topics) > 0:
            return "low"
    
    return "none"


def generate_quick_replies(
    response_text: str,
    user_message: str,
    emotion: str
) -> List[str]:
    """Generate contextual quick reply suggestions"""
    
    # Emotion-based
    if emotion in ["stressed", "anxious", "overwhelmed"]:
        return [
            "这让我感到压力很大",
            "我想聊聊如何应对",
            "有什么具体的方法吗？",
        ]
    
    if emotion in ["excited", "confident", "motivated"]:
        return [
            "我想制定一个行动计划",
            "如何最大化这个机会？",
            "下一步该做什么？",
        ]
    
    # Default exploratory questions
    return [
        "能详细说说吗？",
        "这让我想到了...",
        "我还有一个问题",
        "谢谢，这很有帮助",
    ]


async def generate_session_summary(
    conversation_history: List[Dict],
    user_id: str
) -> Dict:
    """
    Generate session summary using Claude Sonnet
    
    Args:
        conversation_history: Full conversation history
        user_id: User identifier
        
    Returns:
        Dict with summary, insights, action items
    """
    
    try:
        client = get_anthropic_client()
        
        # Build conversation text
        conv_text = "\n".join([
            f"{turn.get('role', 'user')}: {turn.get('content', '')}"
            for turn in conversation_history
        ])
        
        summary_prompt = f"""Analyze this coaching session and provide a structured summary.

Conversation:
{conv_text}

Provide a JSON response with:
{{
  "summary": "2-3 sentence overall summary",
  "key_insights": ["insight 1", "insight 2", "insight 3"],
  "action_items": ["action 1", "action 2"],
  "progress_made": "What progress or breakthroughs happened",
  "recommended_next_steps": ["next step 1", "next step 2"]
}}

Focus on what the coachee discovered, decisions made, and concrete next actions."""
        
        response = await client.messages.create(
            model=CLAUDE_SONNET_4_6,  # Use Sonnet for summaries
            max_tokens=500,
            messages=[{"role": "user", "content": summary_prompt}],
        )
        
        raw = response.content[0].text
        
        # Try to parse JSON
        try:
            # Find JSON in response
            start = raw.find("{")
            end = raw.rfind("}") + 1
            if start != -1 and end > start:
                parsed = json.loads(raw[start:end])
                return {
                    "summary": parsed.get("summary", ""),
                    "key_insights": parsed.get("key_insights", []),
                    "action_items": parsed.get("action_items", []),
                    "progress_made": parsed.get("progress_made", ""),
                    "recommended_next_steps": parsed.get("recommended_next_steps", [])
                }
        except:
            pass
        
        # Fallback
        return {
            "summary": raw[:200] if raw else "Summary generation failed.",
            "key_insights": [],
            "action_items": [],
            "progress_made": "Session completed",
            "recommended_next_steps": []
        }
        
    except Exception as e:
        return {
            "summary": f"Summary generation error: {str(e)}",
            "key_insights": [],
            "action_items": [],
            "progress_made": "Session completed",
            "recommended_next_steps": []
        }
