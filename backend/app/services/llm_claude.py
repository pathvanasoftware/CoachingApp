"""
Three-Model Claude Architecture
================================
Sonnet 4.6  — default, ~90% of conversations   ($3/$15 per MTok)
Opus 4.6    — complex/deep turns, ~10%          ($5/$25 per MTok)
Haiku 4.5   — async background classification   ($1/$5  per MTok)

Auto-upgrade from Sonnet → Opus on:
  1. Conversation length > 40 turns  (long_context)
  2. Complex multi-option decisions  (complex_decision)
  3. Deep self-reflection / patterns (deep_reflection)
  4. Strategic career planning       (strategic_planning)
  5. Escalation risk: medium or high (escalation_prep)

Haiku runs *after* the main response is returned (fire-and-forget) to:
  - Classify escalation risk for the next turn
  - Extract goal updates
  - Generate background session tags
"""

import os
import json
import asyncio
import logging
import re
from dataclasses import asdict, dataclass, field
from typing import Any, Dict, List, Optional, Tuple

from app.services.style_router import route_style, STYLE_PROMPTS
from app.services.emotion_analyzer import detect_emotion
from app.services.context_engine import build_context_packet, infer_goal_link
from app.services.memory_store import load_profile, save_profile, update_profile_from_turn
from app.services.emotion_engine import analyze_text_emotion, infer_context_triggers
from app.services.behavior_tracker import update_behavior_signals, style_preference_shift
from app.services.goal_architecture import (
    infer_goal_hierarchy, build_goal_anchor,
    progressive_skill_building, outcome_prediction,
)
from app.prompts.proprietary_frameworks import get_framework_for_context

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Model IDs  (confirmed from Anthropic docs, 2026-03)
# ---------------------------------------------------------------------------

SONNET = "claude-sonnet-4-6"          # default coaching model
OPUS   = "claude-opus-4-6"            # upgrade for complex turns
HAIKU  = "claude-haiku-4-5"           # async background classifier

# ---------------------------------------------------------------------------
# GROW Coaching System Prompt
# ---------------------------------------------------------------------------

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

**Inquiry-First Rule:**
- For early turns (or when details are sparse), prioritize diagnosis over advice.
- Ask exactly one high-leverage clarifying question before giving recommendations.
- Do not present multi-point frameworks or long explanations until enough specifics are known.
- Once context is clear, provide one concise recommendation plus one follow-up question.

**Crisis Protocol:**
If someone explicitly expresses thoughts of self-harm or suicide:
1. Express genuine concern
2. Provide crisis resources immediately
3. Recommend professional help
4. Do not attempt to provide therapy

**Coaching-Appropriate Topics:**
Career stress, burnout, overwhelm, work-life balance, job dissatisfaction, and professional
challenges are all appropriate for coaching. These are NOT crises. Coach them normally
with empathy and strategic guidance.

Crisis Resources (only for explicit self-harm/suicide):
- National Suicide Prevention Lifeline: 988 (US)
- Crisis Text Line: Text HOME to 741741
- International: https://findahelpline.com

Always maintain a warm, professional, and supportive tone.
Keep responses concise but meaningful.
Hard limits per turn:
- Maximum 120 words
- Ask at most one question total
- Prefer one short paragraph and one concrete next step"""


def _enforce_response_limits(text: str) -> str:
    """Enforce concise output and at most one question mark."""
    if not text:
        return text

    cleaned = " ".join(text.strip().split())

    # Word budget
    words = cleaned.split(" ")
    if len(words) > 120:
        cleaned = " ".join(words[:120]).rstrip(" ,;:-") + "..."

    # At most one question overall (support both ASCII and full-width marks)
    q_count = 0
    out_chars: List[str] = []
    for ch in cleaned:
        if ch in ("?", "？"):
            q_count += 1
            out_chars.append(ch if q_count == 1 else ".")
        else:
            out_chars.append(ch)

    return "".join(out_chars)


def _count_user_turns(history: List[Dict], current_message: str) -> int:
    prior_user_turns = sum(1 for h in history if (h.get("role") or "").lower() == "user")
    return prior_user_turns + (1 if (current_message or "").strip() else 0)


def _is_context_rich(message: str) -> bool:
    """
    Heuristic: context is rich when at least two specificity signals are present.
    Signals: timeframe, stakeholders/team, metrics/symptoms, concrete events.
    """
    m = (message or "").lower()

    timeframe = bool(re.search(r"\b(today|this week|next week|q[1-4]|quarter|month|by friday|deadline|timeline)\b", m))
    stakeholders = bool(re.search(r"\b(manager|team|vp|director|peer|stakeholder|customer|client)\b", m))
    metrics = bool(re.search(r"\b(kpi|metric|revenue|churn|quality|defect|missed|late|throughput|performance)\b", m))
    events = bool(re.search(r"\b(reorg|launch|incident|handoff|meeting|review|retro|1:1|one-on-one)\b", m))

    signals = sum([timeframe, stakeholders, metrics, events])
    return signals >= 2


def _build_clarifying_question(message: str) -> str:
    m = (message or "").lower()
    if "performance" in m or "team" in m:
        return "Which part is slipping most right now: quality, speed, or ownership?"
    if "stuck" in m or "off" in m:
        return "What specific moment this week made you feel most stuck?"
    if "conflict" in m or "manager" in m or "boss" in m:
        return "What is the exact conversation you are avoiding right now?"
    if "priority" in m or "overwhelm" in m or "busy" in m:
        return "If you could solve only one thing this week, what would create the biggest relief?"
    return "What is the single most important outcome you need from this situation this week?"


def _is_broad_problem_statement(message: str) -> bool:
    m = (message or "").lower()
    broad_markers = [
        "slipping", "stuck", "off", "not sure", "uncertain", "overwhelmed",
        "burnout", "things are off", "team performance", "isn't working",
    ]
    specific_request_markers = [
        "strategy", "plan", "framework", "negotiate", "script", "decision",
        "job offer", "promotion", "trade-off", "options", "roadmap",
    ]
    has_broad_marker = any(k in m for k in broad_markers)
    has_specific_request = any(k in m for k in specific_request_markers)
    return has_broad_marker and not has_specific_request


def _is_specific_request(message: str) -> bool:
    m = (message or "").lower()
    specific_request_markers = [
        "strategy", "plan", "framework", "negotiate", "script", "decision",
        "job offer", "promotion", "trade-off", "options", "roadmap",
        "how do i", "help me", "what should i do", "give me",
    ]
    return any(k in m for k in specific_request_markers)


@dataclass
class ConversationSignals:
    stakeholder: Optional[str] = None
    outcome: Optional[str] = None
    example: Optional[str] = None
    timeframe: Optional[str] = None
    constraint: Optional[str] = None
    leaning: Optional[str] = None
    topic_signature: List[str] = field(default_factory=list)


_STAGE_ORDER = ["diagnose", "reframe", "options", "commit"]


def _extract_topic_signature(message: str) -> List[str]:
    m = (message or "").lower()
    keyword_groups = [
        ("trust", r"\btrust\b"),
        ("stakeholder", r"\bstakeholder\b"),
        ("manager", r"\b(manager|boss|supervisor)\b"),
        ("team", r"\bteam\b"),
        ("performance", r"\b(performance|underperformance|slipping|quality|kpi|metric)\b"),
        ("promotion", r"\b(promotion|raise|level up|career growth)\b"),
        ("conflict", r"\b(conflict|tension|pushback|friction)\b"),
        ("burnout", r"\b(burnout|overwhelm|overwhelmed|stress|stressed)\b"),
        ("priority", r"\b(priority|prioritization|trade-off|focus)\b"),
        ("deadline", r"\b(deadline|by friday|timeline|due date|q[1-4]|quarter)\b"),
        ("reorg", r"\b(reorg|re-?org|restructure|headcount|budget)\b"),
        ("career", r"\b(career|pivot|transition|new role|job offer|offer)\b"),
    ]

    topics: List[str] = []
    for label, pattern in keyword_groups:
        if re.search(pattern, m):
            topics.append(label)
    return topics[:4]


def _extract_conversation_signals(message: str) -> ConversationSignals:
    m = (message or "").lower()

    stakeholder = None
    for label, pattern in [
        ("manager", r"\b(manager|boss|supervisor|lead)\b"),
        ("team", r"\bteam\b"),
        ("peer", r"\b(peer|colleague)\b"),
        ("stakeholder", r"\bstakeholder\b"),
        ("customer", r"\b(customer|client)\b"),
    ]:
        if re.search(pattern, m):
            stakeholder = label
            break

    outcome = None
    for label, pattern in [
        ("trust", r"\btrust\b"),
        ("promotion", r"\b(promotion|raise|level up)\b"),
        ("alignment", r"\b(alignment|align)\b"),
        ("underperformance", r"\b(underperformance|performance|slipping|missed)\b"),
        ("conflict_resolution", r"\b(conflict|resolve|tension|pushback)\b"),
        ("prioritization", r"\b(priority|prioritize|overwhelm|focus)\b"),
        ("career_transition", r"\b(career pivot|transition|new role|job offer)\b"),
    ]:
        if re.search(pattern, m):
            outcome = label
            break

    example_match = re.search(
        r"\b(yesterday|last week|last month|in (?:the )?(?:meeting|review|retro|1:1|one-on-one)|after the|when we|when i)\b",
        m,
    )
    example = example_match.group(0) if example_match else None

    timeframe_match = re.search(
        r"\b(today|this week|next week|this month|next month|q[1-4]|quarter|by friday|deadline|timeline)\b",
        m,
    )
    timeframe = timeframe_match.group(0) if timeframe_match else None

    constraint_match = re.search(
        r"\b(budget|deadline|headcount|time|resources|reorg|politics|capacity|bandwidth)\b",
        m,
    )
    constraint = constraint_match.group(0) if constraint_match else None

    leaning = None
    if re.search(r"\b(plan|implement|execute|do next|next step|script)\b", m):
        leaning = "action"
    elif re.search(r"\b(strategy|framework|advice|recommend)\b", m):
        leaning = "advice"
    elif re.search(r"\b(explore|think through|understand|unpack)\b", m):
        leaning = "explore"
    elif re.search(r"\b(not sure|uncertain|confused|unclear)\b", m):
        leaning = "clarify"

    return ConversationSignals(
        stakeholder=stakeholder,
        outcome=outcome,
        example=example,
        timeframe=timeframe,
        constraint=constraint,
        leaning=leaning,
        topic_signature=_extract_topic_signature(message),
    )


def _is_user_confused(message: str) -> bool:
    m = (message or "").lower()
    return bool(re.search(r"\b(not sure|uncertain|confused|unclear|lost|not following|don't understand)\b", m))


def _detect_topic_shift(message: str, previous_topics: List[str], current_topics: List[str]) -> bool:
    m = (message or "").lower()
    if re.search(r"\b(different topic|another topic|switch gears|unrelated|separate issue|on another note)\b", m):
        return True

    prev = set(previous_topics or [])
    curr = set(current_topics or [])
    has_soft_shift_cue = bool(re.search(r"\b(anyway|separately|also,? new issue|side note)\b", m))
    if has_soft_shift_cue and prev and curr and not (prev & curr) and len(prev) >= 2 and len(curr) >= 2:
        return True
    return False


def _initial_stage(signals: ConversationSignals, context_rich: bool, is_specific_request: bool) -> Tuple[str, str]:
    if is_specific_request and context_rich and signals.leaning == "action":
        return "options", "initial_specific_action"
    if is_specific_request:
        return "reframe", "initial_specific_request"
    if context_rich and signals.outcome and signals.constraint:
        return "options", "initial_context_rich_options"
    if context_rich and (signals.outcome or signals.example):
        return "reframe", "initial_context_rich_reframe"
    return "diagnose", "initial_default"


def _rollback_stage(stage: str) -> str:
    if stage not in _STAGE_ORDER:
        return "diagnose"
    idx = _STAGE_ORDER.index(stage)
    return _STAGE_ORDER[max(0, idx - 1)]


def _route_stage(
    previous_stage: Optional[str],
    signals: ConversationSignals,
    *,
    user_turn_count: int,
    context_rich: bool,
    is_specific_request: bool,
    topic_shift: bool,
    user_confused: bool,
) -> Tuple[str, str]:
    if topic_shift:
        return "diagnose", "topic_shift"

    if not previous_stage or previous_stage not in _STAGE_ORDER:
        return _initial_stage(signals, context_rich, is_specific_request)

    if user_confused and previous_stage != "diagnose":
        return _rollback_stage(previous_stage), "user_confused"

    if previous_stage == "diagnose":
        if signals.outcome and signals.example:
            return "reframe", "forward_outcome_example"
        if signals.outcome and signals.stakeholder and user_turn_count >= 2:
            return "reframe", "forward_outcome_stakeholder"
        return "diagnose", "hold_diagnose"

    if previous_stage == "reframe":
        if signals.stakeholder and signals.constraint:
            return "options", "forward_stakeholder_constraint"
        if signals.outcome and signals.leaning in {"advice", "action"}:
            return "options", "forward_outcome_leaning"
        return "reframe", "hold_reframe"

    if previous_stage == "options":
        if signals.leaning == "action":
            return "commit", "forward_action_commit"
        return "options", "hold_options"

    return "commit", "hold_commit"


def _count_questions(text: str) -> int:
    return sum(1 for ch in text if ch in ("?", "？"))


def _enforce_diagnose_contract(text: str, message: str) -> Tuple[str, bool]:
    """
    Diagnose contract (hard guardrail):
    - exactly one clarifying question
    - no frameworks/lists
    - no prescriptive advice
    Returns (response_text, rewritten_flag).
    """
    cleaned = " ".join((text or "").strip().split())
    if not cleaned:
        return f"Thanks for naming that. {_build_clarifying_question(message)}", True

    lower = cleaned.lower()
    question_count = _count_questions(cleaned)
    has_numbered_list = bool(re.search(r"(?:^|\s)\d+\.", lower))
    has_framework_pattern = bool(re.search(r"\b(first\b|second\b|third\b|framework\b|strategy\b|approach\b|roadmap\b|step-by-step\b)\b", lower))
    has_prescriptive_advice = bool(re.search(r"\b(you should|should\b|need to|must\b|recommend\b|suggest\b|start by|focus on|here'?s what to do)\b", lower))

    violates_contract = (
        question_count != 1
        or has_numbered_list
        or has_framework_pattern
        or has_prescriptive_advice
    )
    if not violates_contract:
        return cleaned, False

    return f"Thanks for naming that. {_build_clarifying_question(message)}", True


def _enforce_inquiry_first(text: str, message: str, should_enforce: bool) -> Tuple[str, bool]:
    if not should_enforce:
        return text, False
    return _enforce_diagnose_contract(text, message)


INTERNAL_PERSONA_PROMPTS: Dict[str, str] = {
    "supportive": (
        "Internal persona: supportive coach voice. Be calm, emotionally validating, and psychologically safe. "
        "Use gentle challenge and avoid aggressive framing."
    ),
    "challenger": (
        "Internal persona: challenger coach voice. Be direct, concise, and accountability-oriented without being hostile. "
        "Push for specificity and ownership."
    ),
}


def _extract_session_id(context: Optional[str]) -> Optional[str]:
    if not context:
        return None
    marker = "session_id="
    idx = context.find(marker)
    if idx == -1:
        return None
    raw = context[idx + len(marker):].strip()
    if not raw:
        return None
    # context today is a compact string; keep only first token
    return raw.split()[0]


def _select_internal_persona(
    emotion_primary: str,
    style_used: str,
    stage: str,
) -> Tuple[str, str]:
    """Return (persona_used, override_reason) with deterministic priority."""
    supportive_emotions = {"high_stress", "low_confidence", "frustration", "distressed"}

    if emotion_primary in supportive_emotions:
        return "supportive", "emotion_distress"
    if style_used == "supportive":
        return "supportive", "style_stabilize"
    if stage == "commit":
        return "challenger", "stage_commit"
    if style_used in {"directive", "strategic"}:
        return "challenger", "style_advise_plan"
    return "supportive", "default"

# ---------------------------------------------------------------------------
# Client helpers
# ---------------------------------------------------------------------------

def _anthropic_available() -> bool:
    return bool(os.getenv("ANTHROPIC_API_KEY"))

def _openai_available() -> bool:
    return bool(os.getenv("OPENAI_API_KEY"))

def _get_anthropic_client():
    from anthropic import AsyncAnthropic
    return AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

# ---------------------------------------------------------------------------
# Model selection  (Sonnet → Opus auto-upgrade)
# ---------------------------------------------------------------------------

def select_model(
    conversation_history: List[Dict],
    current_message: str,
    user_context: Optional[Dict] = None,
) -> Tuple[str, List[str]]:
    """
    Return (model_id, upgrade_reasons).
    Defaults to Sonnet; upgrades to Opus if any signal fires.
    """
    if user_context is None:
        user_context = {}

    upgrade_signals: List[str] = []

    # 1. Long context
    if len(conversation_history) > 40:
        upgrade_signals.append("long_context")

    msg = current_message.lower()

    # 2. Complex decision
    if any(kw in msg for kw in [
        "job offer", "multiple offers", "should i choose",
        "trade-off", "权衡", "多个选择", "难以决定",
    ]):
        upgrade_signals.append("complex_decision")

    # 3. Deep reflection
    if any(kw in msg for kw in [
        "i don't know why", "self-sabotage", "pattern",
        "为什么我总是", "自我破坏", "深层原因",
    ]):
        upgrade_signals.append("deep_reflection")

    # 4. Strategic planning
    if any(kw in msg for kw in [
        "career pivot", "5 year plan", "long-term",
        "职业转型", "长期规划", "战略",
    ]):
        upgrade_signals.append("strategic_planning")

    # 5. Escalation risk from previous Haiku pass
    if user_context.get("escalation_risk") in ("medium", "high"):
        upgrade_signals.append("escalation_prep")

    model = OPUS if upgrade_signals else SONNET
    return model, upgrade_signals

# ---------------------------------------------------------------------------
# Core Claude call  (used by both Sonnet/Opus and Haiku paths)
# ---------------------------------------------------------------------------

async def _claude_complete(
    model: str,
    system: str,
    messages: List[Dict],
    max_tokens: int = 800,
) -> str:
    """Call Claude API and return the response text."""
    client = _get_anthropic_client()
    kwargs: Dict = dict(model=model, max_tokens=max_tokens, messages=messages)
    if system:
        kwargs["system"] = system
    response = await client.messages.create(**kwargs)
    for block in response.content:
        if hasattr(block, "text"):
            return block.text
    return ""

# ---------------------------------------------------------------------------
# OpenAI fallback  (if ANTHROPIC_API_KEY is absent)
# ---------------------------------------------------------------------------

async def _openai_complete(messages: List[Dict], max_tokens: int = 800) -> str:
    from openai import AsyncOpenAI
    client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))
    resp = await client.chat.completions.create(
        model="gpt-4",
        messages=messages,
        max_tokens=max_tokens,
        temperature=0.7,
    )
    return resp.choices[0].message.content or ""

# ---------------------------------------------------------------------------
# Haiku: async background classifier  (fire-and-forget)
# ---------------------------------------------------------------------------

async def _haiku_classify(user_id: str, message: str, response_text: str) -> Dict:
    """
    Run Haiku in the background after the main response is sent.
    Classifies escalation risk, extracts goal updates, tags the session.
    Results are saved to the user profile for use in the *next* turn.
    """
    try:
        prompt = f"""Analyze this coaching exchange and return ONLY valid JSON.

User said: {message}
Coach replied: {response_text}

Return:
{{
  "escalation_risk": "none|low|medium|high",
  "escalation_reason": "one sentence or null",
  "goal_update": "detected goal or null",
  "session_tags": ["tag1", "tag2"]
}}"""

        raw = await _claude_complete(
            model=HAIKU,
            system="You are a coaching session classifier. Return only valid JSON, no prose.",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=200,
        )

        start, end = raw.find("{"), raw.rfind("}") + 1
        if start != -1 and end > start:
            result = json.loads(raw[start:end])
        else:
            result = {}

        # Persist so select_model can read escalation_risk next turn
        profile = load_profile(user_id) or {}
        profile["escalation_risk"]  = result.get("escalation_risk", "none")
        profile["escalation_reason"] = result.get("escalation_reason")
        profile["session_tags"]     = result.get("session_tags", [])
        if result.get("goal_update"):
            profile["active_goal"] = result["goal_update"]
        save_profile(user_id, profile)

        return result

    except Exception as exc:
        logger.warning("Haiku classifier failed (non-fatal): %s", exc)
        return {}

# ---------------------------------------------------------------------------
# Quick-reply generation  (rule-based, no extra LLM call)
# ---------------------------------------------------------------------------

def _generate_quick_replies(user_message: str, ai_response: str, context: Optional[str] = None) -> List[str]:
    user  = (user_message or "").lower()
    coach = (ai_response  or "").lower()
    options: List[str] = ["Tell me more"]

    if any(k in user for k in ["promotion", "raise", "salary", "compensation"]):
        options += ["How do I negotiate this?", "What proof should I prepare?"]
    if any(k in user for k in ["switch", "change career", "transition", "new role"]):
        options += ["How do I de-risk this?", "What's my 30-60-90 day plan?"]
    if any(k in user for k in ["team", "manager", "leadership", "conflict", "boss"]):
        options += ["How should I handle this?", "Give me a script"]
    if any(k in user for k in ["stuck", "overwhelmed", "burnout", "stress"]):
        options += ["Help me prioritize", "What's the smallest next action?"]
    if any(k in user for k in ["job offer", "multiple offers", "should i choose"]):
        options += ["Walk me through the trade-offs", "What questions should I ask?"]

    if any(k in coach for k in ["goal", "achieve", "outcome"]):
        options.append("Let's define the exact goal")
    if any(k in coach for k in ["option", "choice", "alternative"]):
        options.append("Show me 3 options")
    if any(k in coach for k in ["action", "step", "plan"]):
        options.append("Turn this into an action plan")

    if len(options) < 4:
        options += ["What should I do next?", "Help me brainstorm", "I'd like to go deeper"]

    seen, deduped = set(), []
    for opt in options:
        if opt not in seen:
            seen.add(opt)
            deduped.append(opt)
    return deduped[:4]

# ---------------------------------------------------------------------------
# Crisis detection  (unchanged logic from llm.py)
# ---------------------------------------------------------------------------

def _detect_crisis(message: str) -> bool:
    keywords = [
        "suicide", "kill myself", "end my life", "want to die",
        "hurt myself", "no reason to live", "better off dead",
    ]
    m = message.lower()
    return any(k in m for k in keywords)

def _crisis_response() -> str:
    return (
        "I'm concerned about what you're sharing. Your wellbeing matters, "
        "and there are people who can help right now:\n\n"
        "**Immediate Support:**\n"
        "- National Suicide Prevention Lifeline: Call or text **988** (US)\n"
        "- Crisis Text Line: Text **HOME** to **741741**\n"
        "- International: https://findahelpline.com\n\n"
        "These services are free, confidential, and available 24/7. "
        "Would you like to talk about what's going on?"
    )

# ---------------------------------------------------------------------------
# Main coaching response
# ---------------------------------------------------------------------------

async def get_coaching_response_claude(
    message: str,
    history: Optional[List[Dict]] = None,
    user_id: str = "anonymous",
    coaching_style: Optional[str] = None,
    context: Optional[str] = None,
) -> Dict:
    """
    Primary entry point for the three-model architecture.

    Flow:
      1. Crisis check  → immediate return (no model needed)
      2. select_model  → Sonnet or Opus based on signals
      3. Claude call   → coaching response
      4. Haiku task    → fire-and-forget background classification
    """
    if history is None:
        history = []

    # ── Crisis gate ──────────────────────────────────────────────────────
    if _detect_crisis(message):
        return {
            "response": _crisis_response(),
            "quick_replies": ["I'm safe, thanks", "I need to talk to someone", "Find professional help"],
            "style_used": "supportive",
            "emotion_detected": "distressed",
            "goal_link": "wellbeing_first",
            "emotion_primary": "high_stress",
            "model_used": None,
            "upgrade_reasons": [],
        }

    # ── Context signals ───────────────────────────────────────────────────
    emotion    = detect_emotion(message)
    style_used = coaching_style or route_style(message, coaching_style, emotion)
    goal_link  = infer_goal_link(message)
    ei         = analyze_text_emotion(message)
    ctx_triggers = infer_context_triggers(message)

    profile        = load_profile(user_id) or {}
    goal_hierarchy = infer_goal_hierarchy(message, goal_link, profile)
    goal_anchor    = build_goal_anchor(goal_link, goal_hierarchy)
    framework      = get_framework_for_context(message, emotion, goal_link)

    # Deterministic stage routing: signal extraction + per-session state.
    user_turn_count = _count_user_turns(history, message)
    early_turn = user_turn_count <= 3
    session_id = _extract_session_id(context)
    session_state = profile.get("session_state", {}) if isinstance(profile.get("session_state", {}), dict) else {}
    session_entry: Dict[str, Any] = {}
    if session_id:
        raw_session_entry = session_state.get(session_id)
        if isinstance(raw_session_entry, dict):
            session_entry = raw_session_entry

    raw_state_rev = session_entry.get("state_rev", 0)
    pre_state_rev = int(raw_state_rev) if isinstance(raw_state_rev, int) else 0
    post_state_rev = pre_state_rev

    previous_stage = session_entry.get("stage") if isinstance(session_entry.get("stage"), str) else None
    raw_previous_topics = session_entry.get("topic_signature")
    previous_topics = [str(t) for t in raw_previous_topics if isinstance(t, str)] if isinstance(raw_previous_topics, list) else []

    signals = _extract_conversation_signals(message)
    is_specific_request = _is_specific_request(message)
    context_rich = _is_context_rich(message) or bool(signals.outcome and (signals.example or signals.timeframe or signals.constraint))
    topic_shift = _detect_topic_shift(message, previous_topics, signals.topic_signature)
    user_confused = _is_user_confused(message)

    stage, stage_reason = _route_stage(
        previous_stage,
        signals,
        user_turn_count=user_turn_count,
        context_rich=context_rich,
        is_specific_request=is_specific_request,
        topic_shift=topic_shift,
        user_confused=user_confused,
    )
    enforce_inquiry_first = stage == "diagnose"

    # Internal persona routing with per-session lock
    locked_persona = None
    if session_id:
        locked_persona = session_entry.get("persona")

    if locked_persona in INTERNAL_PERSONA_PROMPTS:
        persona_used = locked_persona
        persona_override_reason = "session_lock"
    else:
        persona_used, persona_override_reason = _select_internal_persona(
            emotion_primary=ei.primary,
            style_used=style_used,
            stage=stage,
        )
    # ── Model selection ───────────────────────────────────────────────────
    user_context = {"escalation_risk": profile.get("escalation_risk", "none")}
    model, upgrade_reasons = select_model(history, message, user_context)

    # ── Build system prompt ───────────────────────────────────────────────
    style_prompt = STYLE_PROMPTS.get(style_used, "")
    system = "\n\n".join(filter(None, [
        GROW_SYSTEM_PROMPT,
        INTERNAL_PERSONA_PROMPTS.get(persona_used),
        f"Coaching style this turn: {style_used}. {style_prompt}",
        f"Enhanced with thought leader framework:\n{framework}" if (framework and stage != "diagnose") else None,
        f"Emotion detected: {emotion}. Goal alignment: {goal_link}.",
        f"Persistent profile: {json.dumps(profile, ensure_ascii=False)}",
        f"Goal hierarchy: {json.dumps(goal_hierarchy, ensure_ascii=False)}",
        f"Goal anchor: {goal_anchor}",
        "Structure each turn: (1) brief acknowledgment, (2) one diagnostic question OR one concise recommendation, (3) one concrete next step only when enough context exists.",
        "If the user message is broad (e.g., 'performance is slipping', 'I feel stuck', 'things are off'), ask one clarifying question first and avoid giving a long diagnosis.",
        f"Conversation stage: {stage}.",
        f"Stage routing: previous_stage={previous_stage or 'none'}, stage_reason={stage_reason}, topic_shift={str(topic_shift).lower()}, user_confused={str(user_confused).lower()}.",
        f"Turn diagnostics: user_turn_count={user_turn_count}, context_rich={str(context_rich).lower()}, enforce_inquiry_first={str(enforce_inquiry_first).lower()}.",
        "If enforce_inquiry_first is true: ask exactly one clarifying question and avoid frameworks/advice lists in this turn.",
        build_context_packet(message, [{"role": h.get("role","user"), "content": h.get("content","")} for h in history], context),
        "Return ONLY valid JSON: {\"response\": string, \"quick_replies\": [string×4], \"suggested_actions\": [string]}. "
        "quick_replies must be 3-8 words, user-selectable, tailored to the message. No markdown outside JSON.",
        "response must be <=120 words and include at most one question mark total.",
    ]))

    # ── Trim history ──────────────────────────────────────────────────────
    trimmed = history[:2] + history[-10:] if len(history) > 20 else history
    messages = [{"role": h.get("role", "user"), "content": h.get("content", "")} for h in trimmed]
    messages.append({"role": "user", "content": message})

    # ── LLM call ─────────────────────────────────────────────────────────
    llm_succeeded = False
    try:
        if _anthropic_available():
            raw = await _claude_complete(model=model, system=system, messages=messages, max_tokens=800)
        elif _openai_available():
            # OpenAI doesn't have the same tiering; use gpt-4 flat
            raw = await _openai_complete([{"role": "system", "content": system}] + messages)
            model = "gpt-4 (fallback)"
            upgrade_reasons = []
        else:
            raise ValueError("No LLM API key configured.")

        # Parse JSON response
        start, end = raw.find("{"), raw.rfind("}") + 1
        if start != -1 and end > start:
            parsed = json.loads(raw[start:end])
            ai_response = parsed.get("response", "").strip() or raw.strip()
            quick_replies = [str(x).strip() for x in parsed.get("quick_replies", []) if str(x).strip()][:4]
            sa = parsed.get("suggested_actions")
            suggested_actions = [str(x).strip() for x in sa if str(x).strip()] if isinstance(sa, list) else None
        else:
            ai_response = raw.strip() or "I'm here to help. Could you tell me more?"
            quick_replies = []
            suggested_actions = None

        ai_response, diagnose_rewritten = _enforce_inquiry_first(ai_response, message, stage == "diagnose")
        ai_response = _enforce_response_limits(ai_response)

        if diagnose_rewritten:
            quick_replies = _generate_quick_replies(message, ai_response, context)
        elif len(quick_replies) < 2:
            quick_replies = _generate_quick_replies(message, ai_response, context)

        llm_succeeded = True

    except Exception as exc:
        logger.error("LLM call failed: %s", exc)
        ai_response = "I'm here to help you work through this. Could you tell me more about what's on your mind?"
        quick_replies = _generate_quick_replies(message, ai_response)
        suggested_actions = None
        model = f"error: {exc}"
        upgrade_reasons = []

    # ── Update profile ────────────────────────────────────────────────────
    if session_id and llm_succeeded:
        session_entry["persona"] = persona_used
        session_entry["stage"] = stage
        session_entry["stage_reason"] = stage_reason
        session_entry["turn_count"] = user_turn_count
        session_entry["topic_signature"] = signals.topic_signature
        session_entry["signals"] = asdict(signals)
        session_entry["state_rev"] = pre_state_rev + 1
        post_state_rev = pre_state_rev + 1
        session_state[session_id] = session_entry

    profile = update_profile_from_turn(
        user_id, message, goal_link,
        style_used=style_used,
        emotion_primary=ei.primary,
        context_triggers=ctx_triggers,
    )
    if session_id and isinstance(session_state, dict) and session_state:
        profile["session_state"] = session_state
    profile = update_behavior_signals(profile, style_used=style_used, goal_link=goal_link)
    save_profile(user_id, profile)
    style_shift = style_preference_shift(profile)

    # ── Fire-and-forget Haiku classification ──────────────────────────────
    if _anthropic_available():
        asyncio.ensure_future(_haiku_classify(user_id, message, ai_response))

    return {
        "response":                  ai_response,
        "quick_replies":             quick_replies,
        "suggested_actions":         suggested_actions,
        "style_used":                style_used,
        "emotion_detected":          emotion,
        "goal_link":                 goal_link,
        "model_used":                model,
        "upgrade_reasons":           upgrade_reasons,
        "emotion_primary":           ei.primary,
        "emotion_scores":            ei.scores,
        "sentiment":                 ei.sentiment,
        "linguistic_markers":        ei.linguistic_markers,
        "behavior_signals": {
            "style_preference_shift":    style_shift,
            "session_event_count":       len(profile.get("session_events", [])),
            "persona_used":              persona_used,
            "persona_override_reason":   persona_override_reason,
            "stage_used":                stage,
            "stage_reason":              stage_reason,
            "topic_shift":               topic_shift,
            "pre_state_rev":            pre_state_rev,
            "post_state_rev":           post_state_rev,
        },
        "context_triggers":          ctx_triggers,
        "recommended_style_shift":   style_shift,
        "goal_hierarchy":            goal_hierarchy,
        "goal_anchor":               goal_anchor,
        "progressive_skill_building": progressive_skill_building(style_used, ei.primary),
        "outcome_prediction":        outcome_prediction(goal_link, ei.primary, style_shift),
    }

# ---------------------------------------------------------------------------
# Session summary  (Sonnet — no upgrade needed for summarisation)
# ---------------------------------------------------------------------------

async def generate_session_summary_claude(
    messages: List[Dict],
    user_id: str = "anonymous",
) -> Dict:
    """Generate a session summary using Sonnet."""
    if not messages or len(messages) < 2:
        return {
            "summary": "Session just started — no summary available yet.",
            "key_insights": [], "action_items": [],
            "progress_made": "Beginning of conversation",
            "recommended_next_steps": [],
        }

    conv_text = "\n".join(
        f"{'User' if m.get('role') == 'user' else 'Coach'}: {m.get('content', '')}"
        for m in messages
    )

    prompt = f"""Analyze this coaching session and return ONLY valid JSON.

{conv_text}

{{
  "summary": "2-3 sentence overview",
  "key_insights": ["insight 1", "insight 2", "insight 3"],
  "action_items": ["action 1", "action 2"],
  "progress_made": "what progress or breakthroughs happened",
  "recommended_next_steps": ["next step 1", "next step 2"]
}}"""

    try:
        if _anthropic_available():
            raw = await _claude_complete(
                model=SONNET,
                system="You are an expert at summarising coaching sessions. Return only valid JSON.",
                messages=[{"role": "user", "content": prompt}],
                max_tokens=500,
            )
        elif _openai_available():
            raw = await _openai_complete(
                [
                    {"role": "system", "content": "Summarise coaching sessions as JSON."},
                    {"role": "user", "content": prompt},
                ],
                max_tokens=500,
            )
        else:
            raise ValueError("No LLM API key configured.")

        start, end = raw.find("{"), raw.rfind("}") + 1
        if start != -1 and end > start:
            parsed = json.loads(raw[start:end])
            return {
                "summary":                 parsed.get("summary", ""),
                "key_insights":            parsed.get("key_insights", []),
                "action_items":            parsed.get("action_items", []),
                "progress_made":           parsed.get("progress_made", ""),
                "recommended_next_steps":  parsed.get("recommended_next_steps", []),
            }
    except Exception as exc:
        logger.error("Summary generation failed: %s", exc)

    return {
        "summary": "Summary generation failed.",
        "key_insights": [], "action_items": [],
        "progress_made": "Session completed",
        "recommended_next_steps": [],
    }
