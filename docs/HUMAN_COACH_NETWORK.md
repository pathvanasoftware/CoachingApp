# Human Coach Network & Escalation System

## Overview

This document outlines when and how the app escalates users to human coaches, and how to build a high-quality coach network.

---

## Part 1: Escalation Criteria (When to Suggest Human Coach)

### 🚨 Escalation Categories & Triggers

The app monitors conversations in real-time using an **async escalation classifier** (runs after each AI response, non-blocking).

| Category | Trigger Signal | Urgency | Action |
|----------|---------------|---------|--------|
| **Complex Career Decision** | Multi-stakeholder decisions with political/strategic dimensions (reorg, board conflict, M&A, layoffs) | Medium | Offer deep-dive with human coach |
| **Repeated Loops** | Same topic surfaces 3+ times across sessions without progress | Medium | AI flags pattern, suggests human coach |
| **User Request** | User explicitly asks for a human ("Can I talk to a real person?") | High | Immediate booking flow |
| **Topic Boundary** | Legal advice, financial planning, mental health symptoms, clinical territory | High | Decline topic + redirect to human coach |
| **Personal Crisis Spillover** | User discusses divorce, grief, severe burnout, personal trauma beyond career impact | Medium | Acknowledge briefly, reframe to career impact, suggest human coach |
| **High-Stakes Negotiation** | Compensation negotiation, exit package, co-founder disputes, board presentations | Medium | Suggest human coach for role-play and strategy |
| **Low Engagement** | User gives <5 word responses for 4+ consecutive turns | Low | AI adjusts approach; if persists, suggest human or reschedule |
| **Org-Political Sensitivity** | Situations involving HR investigations, legal exposure, whistleblowing, ethics violations | High | **Do not coach** - redirect to human coach + suggest legal counsel |
| **Crisis (Immediate)** | Explicit self-harm, suicide ideation, safety concerns | **CRITICAL** | Surface crisis resources (988) + notify ops team + offer human coach |

---

### 🤖 How Escalation Works (Technical)

#### Architecture

```
User Message
     │
     ▼
AI Generates Response
     │
     ▼ (async, non-blocking)
┌──────────────────────────────────┐
│  Escalation Classifier           │
│  Model: GPT-4o-mini              │
│                                  │
│  Input:                          │
│  - Last 5 conversation turns     │
│  - User profile (tenure, tier)   │
│  - Session metadata              │
│  - Escalation history            │
│                                  │
│  Output (JSON):                  │
│  {                               │
│    "escalation_needed": bool,    │
│    "urgency": "low|med|high",    │
│    "category": string,           │
│    "reasoning": string,          │
│    "suggested_coach_specialty":  │
│       string                     │
│  }                               │
└──────────┬───────────────────────┘
           │
     ┌─────▼──────┐
     │  Threshold  │
     │  Engine     │
     └─────┬──────┘
           │
    ┌──────┴──────────────────┐
    │                          │
    ▼                          ▼
No Action              Trigger Escalation
                              │
                    ┌─────────▼──────────┐
                    │ Escalation Handler  │
                    │                     │
                    │ 1. Soft: In-chat    │
                    │    suggestion to    │
                    │    book human coach │
                    │                     │
                    │ 2. Urgent: Push     │
                    │    notification +   │
                    │    direct booking   │
                    │    link             │
                    │                     │
                    │ 3. Crisis: Surface  │
                    │    resources +      │
                    │    notify ops team  │
                    └─────────────────────┘
```

#### Escalation Classifier Prompt

```python
ESCALATION_CLASSIFIER_PROMPT = """
Analyze this coaching conversation and determine if human coach 
escalation is needed.

Conversation (last 5 turns):
{conversation_turns}

User context:
- Sessions completed: {session_count}
- Current goals: {goals_summary}
- Subscription tier: {tier}
- Previous escalations: {escalation_history}

Escalation Categories:
1. complex_decision - Multi-stakeholder strategic decisions (reorg, M&A, board conflicts)
2. repeated_loop - Same topic 3+ times without progress
3. user_request - User explicitly asks for human
4. topic_boundary - Legal, financial, clinical territory
5. personal_crisis - Personal trauma beyond career impact
6. high_stakes - Compensation, exit packages, co-founder disputes
7. low_engagement - <5 word responses for 4+ turns
8. org_political - HR investigations, legal exposure, whistleblowing
9. crisis - Self-harm, suicide ideation, safety concerns

Respond in JSON only:
{
  "escalation_needed": true/false,
  "urgency": "low" | "medium" | "high" | "critical",
  "category": "complex_decision" | "repeated_loop" | "user_request" | 
    "topic_boundary" | "personal_crisis" | "high_stakes" | 
    "low_engagement" | "org_political" | "crisis" | "none",
  "reasoning": "Brief explanation of why escalation is/isn't needed",
  "suggested_coach_specialty": "leadership" | "transitions" | 
    "communication" | "strategy" | "wellbeing" | "crisis" | null
}
"""
```

---

### 📱 User Experience (What Users See)

#### Soft Escalation (Medium Urgency)

```
┌──────────────────────────────────────────────┐
│ 💡 This seems like a complex situation that  │
│    might benefit from deeper exploration     │
│                                              │
│ Would you like to schedule a session with    │
│ a human coach who specializes in             │
│ {specialty}?                                 │
│                                              │
│ [View Available Coaches]  [Maybe Later]      │
└──────────────────────────────────────────────┘
```

#### Urgent Escalation (High Urgency)

```
┌──────────────────────────────────────────────┐
│ ⚠️ This situation involves legal/ethical     │
│    considerations that are beyond AI         │
│    coaching scope.                           │
│                                              │
│ I recommend talking to a human coach who     │
│ can provide proper guidance.                 │
│                                              │
│ [Book Now - Available Today]                 │
│ [View Coach Profiles]                        │
└──────────────────────────────────────────────┘
```

#### Crisis Escalation (Critical)

```
┌──────────────────────────────────────────────┐
│ 🆘 If you're in crisis, please reach out:    │
│                                              │
│ 📞 988 Suicide & Crisis Lifeline             │
│ 📱 Crisis Text Line: Text HOME to 741741     │
│                                              │
│ ─────────────────────────────────────────    │
│                                              │
│ I'm also here to help you find a human       │
│ coach who can support you through this.      │
│                                              │
│ [Talk to a Coach Now]  [View Resources]      │
└──────────────────────────────────────────────┘
```

---

## Part 2: Building the Human Coach Network

### 🎯 Coach Network Strategy

#### Phase 1: Pilot (Months 1-6)
**Goal:** 5-10 hand-picked coaches from co-founder's network

**Why:**
- Highest quality control
- Deep alignment with proprietary methodology
- Fast iteration on coach-AI handoff process
- Strong margins (no platform fees)

**Criteria:**
- 10+ years executive coaching experience
- Fortune 500/tech company background
- Trained in co-founder's methodology (in-person workshop)
- Available minimum 10 hours/week
- Willing to provide feedback on AI coaching quality

**Compensation:**
- $200-400/hour (depending on seniority)
- Revenue share model: 70% to coach, 30% to platform
- Guaranteed minimum hours during pilot

---

#### Phase 2: Expansion (Months 6-18)
**Goal:** 20-50 coaches with specialty coverage

**Specialty Areas:**
1. **Leadership Development** (40% of demand)
   - New manager transitions
   - Executive presence
   - Team building
   
2. **Career Transitions** (25% of demand)
   - Industry pivots
   - Promotion acceleration
   - Exit strategy
   
3. **Communication & Influence** (20% of demand)
   - Stakeholder management
   - Difficult conversations
   - Negotiation
   
4. **Strategic Thinking** (10% of demand)
   - Strategic planning
   - Decision frameworks
   - Organizational design
   
5. **Wellbeing & Burnout** (5% of demand)
   - Work-life integration
   - Stress management
   - Resilience building

**Vetting Process:**
1. **Application Review** (automated + manual)
   - Resume/CV analysis
   - Client testimonials (minimum 5)
   - Video introduction
   
2. **Methodology Training** (required)
   - 8-hour online certification course
   - Assessment: coach 2 practice sessions
   - Feedback from co-founder
   
3. **Trial Period** (first 10 sessions)
   - All sessions reviewed by senior coach
   - Client NPS must be >8
   - 80%+ clients would book again
   
4. **Ongoing Quality Control**
   - Monthly peer supervision
   - Quarterly client feedback review
   - Annual recertification

---

#### Phase 3: Scale (Months 18+)
**Decision Point:** Build vs Partner

**Option A: Build Own Network (Recommended for Quality)**
- Continue vetting and training coaches
- Build coach-facing portal (session briefs, client notes)
- Implement AI-assisted coach matching
- Higher margins (70-80% gross margin)
- Slower scaling

**Option B: Partner with Platform (Faster Scaling)**
- Partner with CoachHub, BetterUp, or Torch
- API integration for coach matching
- Lower margins (40-50% gross margin)
- Less quality control
- Faster geographic expansion

**Recommendation:**
- Start with Option A (own network) for first 2 years
- Build strong brand differentiation through quality
- Consider hybrid model: core network + overflow to partners

---

### 💰 Coach Economics

#### Revenue Model

**Enterprise Pricing:**
- Starter: $99/user/month (AI only)
- Professional: $299/user/month (AI + 2 human sessions/month)
- Executive: $599/user/month (AI + 4 human sessions/month)

**Coach Payment:**
- Average session: 60 minutes
- Coach rate: $200-400/hour
- Platform margin: 30%
- Coach earnings: $140-280/session

**Example Economics (50-user enterprise account, Executive tier):**
```
Revenue:
- 50 users × $599/month = $29,950/month

Costs:
- AI costs (Claude): ~$200/month
- Human coaching: 200 sessions × $280 avg = $5,600/month
- Platform costs: ~$500/month

Gross Margin: $29,950 - $6,300 = $23,650 (79%)
```

---

### 🏗️ Coach Matching Algorithm

```python
def match_coach(user_id: str, specialty: str, urgency: str) -> Coach:
    """
    Match user to best available coach
    """
    
    # Get user context
    user = get_user_profile(user_id)
    user_preferences = {
        "industry": user.industry,
        "role": user.title,
        "goals": user.active_goals,
        "previous_coach": user.last_coach_id,
        "language": user.preferred_language,
        "timezone": user.timezone,
    }
    
    # Get available coaches
    available_coaches = get_available_coaches(
        specialty=specialty,
        time_window=get_time_window(urgency),
    )
    
    # Score each coach
    scored_coaches = []
    for coach in available_coaches:
        score = 0
        
        # Specialty match (40%)
        if specialty in coach.specialties:
            score += 40
        
        # Industry experience (20%)
        if user_preferences["industry"] in coach.industries:
            score += 20
        
        # Role experience (15%)
        if similar_roles(user_preferences["role"], coach.client_roles):
            score += 15
        
        # Previous relationship (10%)
        if coach.id == user_preferences["previous_coach"]:
            score += 10
        
        # Rating (10%)
        score += (coach.avg_rating - 4.0) * 10  # 4.0-5.0 → 0-10
        
        # Availability (5%)
        if coach.available_now:
            score += 5
        
        scored_coaches.append((coach, score))
    
    # Return best match
    scored_coaches.sort(key=lambda x: x[1], reverse=True)
    return scored_coaches[0][0]
```

---

### 📊 Coach Network KPIs

#### Quality Metrics
- **Client NPS:** Target >8.0
- **Session Rating:** Target >4.5/5.0
- **Repeat Booking Rate:** Target >70%
- **Escalation Success Rate:** % of escalations that lead to human booking (target >40%)

#### Utilization Metrics
- **Coach Utilization:** Target 60-80% of available hours booked
- **Average Sessions/Coach/Month:** Target 40-60
- **Time to First Session:** Target <24 hours for non-urgent, <4 hours for urgent

#### Business Metrics
- **Coach Retention:** Target >90% annual retention
- **Revenue per Coach:** Target $8,000-15,000/month
- **Coach NPS:** Target >7.0 (coach satisfaction with platform)

---

### 🛠️ Implementation Roadmap

#### MVP (Weeks 1-4)
- [ ] Manual coach matching (ops team handles)
- [ ] Calendly integration for booking
- [ ] Basic coach profile page in app
- [ ] Post-session feedback collection

#### Phase 2 (Weeks 5-12)
- [ ] Automated coach matching algorithm
- [ ] In-app scheduling (replace Calendly)
- [ ] Coach portal (session briefs, client history)
- [ ] Video call integration (Zoom API)

#### Phase 3 (Weeks 13-24)
- [ ] AI-generated session briefs for coaches
- [ ] Coach performance dashboard
- [ ] Peer supervision scheduling
- [ ] Client-coach messaging (async support)

---

### 🎓 Coach Onboarding Checklist

#### Pre-Onboarding
- [ ] Signed contractor agreement
- [ ] Background check completed
- [ ] Insurance verification
- [ ] Banking/tax info collected

#### Training (Week 1)
- [ ] Methodology certification (8-hour course)
- [ ] Platform training (2 hours)
- [ ] Practice sessions (2 sessions with feedback)
- [ ] Escalation protocol training

#### Go-Live (Week 2)
- [ ] Profile created and approved
- [ ] Calendar integrated
- [ ] First 3 sessions scheduled
- [ ] Quality review scheduled

#### Ongoing
- [ ] Monthly peer supervision (1 hour)
- [ ] Quarterly performance review
- [ ] Annual recertification

---

### 📋 Escalation Implementation Checklist

#### Backend
- [ ] Implement escalation classifier (GPT-4o-mini)
- [ ] Create escalation logging table
- [ ] Build coach availability tracking
- [ ] Implement matching algorithm
- [ ] Create booking API endpoint

#### iOS
- [ ] Design escalation UI (soft/urgent/crisis)
- [ ] Implement coach profile view
- [ ] Build scheduling flow
- [ ] Add post-session feedback
- [ ] Push notifications for escalations

#### Operations
- [ ] Create escalation response playbook
- [ ] Set up on-call rotation for crisis escalations
- [ ] Define SLAs (urgent <4h, medium <24h)
- [ ] Create coach notification system

---

## Summary

### Escalation Triggers (When to Suggest Human Coach)
1. ✅ Complex strategic decisions (reorg, M&A, board conflicts)
2. ✅ Repeated loops (3+ times same topic, no progress)
3. ✅ User explicit request
4. ✅ Topic boundaries (legal, financial, clinical)
5. ✅ Personal crisis spillover
6. ✅ High-stakes negotiations
7. ✅ Low engagement (<5 words, 4+ turns)
8. ✅ Org-political sensitivity (HR, legal, whistleblowing)
9. ✅ Crisis (self-harm, suicide ideation)

### Coach Network Build Strategy
1. **Phase 1 (Pilot):** 5-10 coaches from co-founder's network
2. **Phase 2 (Expansion):** 20-50 coaches with specialty coverage
3. **Phase 3 (Scale):** Build own network (recommended) or partner

### Key Success Factors
- **Quality over quantity:** Vetting process is critical
- **Methodology alignment:** All coaches trained in proprietary approach
- **Smart matching:** Algorithm matches coach specialty to user needs
- **Feedback loops:** Continuous quality monitoring
- **Fair compensation:** 70/30 revenue share, $200-400/hour

### Expected Economics
- **Gross margin:** 70-80% (own network) or 40-50% (partner)
- **Revenue per coach:** $8,000-15,000/month
- **Client NPS target:** >8.0
- **Utilization target:** 60-80%
