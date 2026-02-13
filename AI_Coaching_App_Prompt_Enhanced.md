# Executive AI Coaching iOS App — Development Prompt

## 1. Product Overview

Build a native iOS app that delivers AI-powered **career and executive coaching** with intelligent escalation to human coaches. The app is sold **enterprise-first (B2B2C)** — companies purchase licenses for their leadership teams. It offers multiple AI coaching personas built on a **proprietary coaching methodology**, structured goal tracking, and a seamless handoff to live coaches when conversations exceed AI capability boundaries. Supports both **voice and text** interaction from launch.

**Co-founder context:** Former Facebook/Reddit executive with active executive coaching practice. Their proprietary coaching methodology — codified from years of 1:1 executive engagements — is the core IP embedded into the AI coaching engine. This is not generic GROW-model coaching; it is a specific, proven approach to career acceleration and leadership development that cannot be replicated by competitors using off-the-shelf frameworks.

**Core differentiation:**
- **Proprietary methodology as AI moat:** Co-founder's coaching approach encoded directly into system prompts — the AI coaches the way they coach
- **Enterprise-first GTM:** Sold to companies for their leadership teams, not individual consumers
- **Career & executive focus:** Not life coaching, not mental health — specifically career trajectory, leadership effectiveness, stakeholder navigation, and executive presence
- **Voice-native:** Executives prefer talking over typing; voice interaction is first-class from MVP
- **Hybrid AI-human system:** AI handles high-frequency sessions; human coaches handle strategically complex or high-stakes situations

**Explicitly out of scope:** Mental health counseling, therapy, clinical interventions. The app is positioned as professional development and career coaching. This is both a product decision and a compliance simplifier (no HIPAA required).

---

## 2. Technical Architecture

### 2.1 System Architecture (High-Level)

```
┌─────────────────────────────────────────────────────────┐
│                      iOS Client                         │
│  SwiftUI + Combine  │  Local CoreData Cache             │
│  WebSocket Client   │  Keychain (auth tokens)           │
│  Apple Speech (STT) │  AVSpeechSynthesizer (TTS)        │
└──────────┬──────────────────────────────────┬───────────┘
           │ HTTPS/WSS                        │ Push (APNs)
┌──────────▼──────────────────────────────────▼───────────┐
│                   API Gateway (Kong / AWS API GW)       │
│          Rate Limiting │ Auth │ Request Routing          │
└──────────┬──────────────────────────────────────────────┘
           │
┌──────────▼──────────────────────────────────────────────┐
│              Backend Services (Microservices)            │
│                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │ Auth Service │  │ Chat Service │  │ Coach Matching │ │
│  │ (JWT/OAuth)  │  │ (WebSocket)  │  │    Service     │ │
│  └─────────────┘  └──────┬───────┘  └────────────────┘ │
│                          │                               │
│  ┌───────────────────────▼───────────────────────────┐  │
│  │            AI Orchestration Layer                  │  │
│  │  Prompt Management │ Context Window │ Escalation   │  │
│  │  Persona Router    │ Manager        │ Engine       │  │
│  └───────────────────────┬───────────────────────────┘  │
│                          │                               │
│  ┌───────────────────────▼───────────────────────────┐  │
│  │            LLM Provider (Claude API)              │  │
│  │  claude-sonnet-4-5 for coaching sessions          │  │
│  │  claude-haiku-4-5 for classification/routing      │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │  Voice       │  │  Scheduling  │  │  Notification  │ │
│  │  Processing  │  │  Service     │  │  Service       │ │
│  │  Service     │  │              │  │                │ │
│  └─────────────┘  └──────────────┘  └────────────────┘ │
│                                                         │
│  ┌─────────────┐  ┌──────────────┐                     │
│  │  Analytics   │  │  Enterprise  │                     │
│  │  Service     │  │  Admin Svc   │                     │
│  └─────────────┘  └──────────────┘                     │
└─────────────────────────────────────────────────────────┘
           │
┌──────────▼──────────────────────────────────────────────┐
│                    Data Layer                            │
│  PostgreSQL (users, goals, coach profiles, orgs)        │
│  Redis (session state, rate limiting, caching)           │
│  S3 (session transcripts, audio recordings, media)       │
│  Pinecone/pgvector (conversation embeddings for RAG)     │
└─────────────────────────────────────────────────────────┘
```

### 2.2 iOS Client Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| UI Framework | SwiftUI | Declarative, modern, rapid iteration |
| State Management | Combine + @Observable (iOS 17+) | Native reactive patterns |
| Networking | URLSession + async/await | No third-party dependency for HTTP |
| WebSocket | URLSessionWebSocketTask | Native WebSocket for real-time chat |
| Local Storage | SwiftData (CoreData successor) | Structured local caching of sessions |
| Auth Tokens | Keychain Services | Secure credential storage |
| Speech-to-Text | Apple Speech framework (on-device) | Low latency, privacy-preserving, free |
| Text-to-Speech | AVSpeechSynthesizer (MVP) → ElevenLabs/OpenAI TTS (Phase 2) | On-device for MVP; upgrade to natural voice later |
| Audio Streaming | AVAudioEngine + AudioToolbox | Real-time audio capture and playback |
| Push Notifications | APNs via Firebase Cloud Messaging | Reliable cross-platform push |
| Analytics | Mixpanel SDK | Event tracking, funnel analysis |
| Minimum Target | iOS 17.0 | Enables SwiftData, @Observable, improved Speech |

### 2.3 Backend Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Runtime | Node.js (Fastify) or Python (FastAPI) | Fast dev, good LLM ecosystem |
| API Protocol | REST + WebSocket (for chat streaming) | REST for CRUD, WS for real-time |
| Auth | Supabase Auth or Auth0 | OAuth2/OIDC, Apple Sign-In, Google |
| Primary DB | PostgreSQL (via Supabase or RDS) | Relational data, JSONB for flexibility |
| Vector Store | pgvector extension on PostgreSQL | Conversation embeddings without extra infra |
| Cache | Redis (ElastiCache) | Session state, rate limits, token budgets |
| Object Storage | AWS S3 | Session transcripts, exports |
| Task Queue | BullMQ (Redis-backed) | Async jobs: analytics, notifications |
| Hosting | AWS (ECS Fargate) or Fly.io | Container-based, auto-scaling |
| CI/CD | GitHub Actions → ECR → ECS | Standard deployment pipeline |

### 2.4 LLM Integration Architecture

```
User Message
     │
     ▼
┌─────────────────────────────────┐
│     Context Window Manager      │
│                                 │
│  1. Load user profile           │
│  2. Load active goals           │
│  3. Load last N session turns   │
│  4. RAG: retrieve relevant      │
│     past session snippets       │
│  5. Load coaching persona       │
│     system prompt               │
│  6. Assemble final prompt       │
│     (keep under token budget)   │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│     Persona Router              │
│                                 │
│  Select system prompt based on: │
│  - User's chosen coaching style │
│  - Session type (check-in,      │
│    deep-dive, goal review)      │
│  - Escalation state             │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│     Claude API Call             │
│                                 │
│  Model: claude-sonnet-4-5       │
│  Streaming: enabled (SSE)       │
│  Max tokens: 1024 per response  │
│  Temperature: 0.7 (coaching)    │
│  System prompt: persona +       │
│    coaching methodology +       │
│    escalation instructions      │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│  Post-Processing Pipeline       │
│                                 │
│  1. Stream tokens to client     │
│  2. Run escalation classifier   │
│     (Haiku, async)              │
│  3. Extract goal updates        │
│  4. Log session metrics         │
│  5. Update conversation         │
│     embeddings                  │
└─────────────────────────────────┘
```

**Token Budget Management:**
Each user tier gets a daily/monthly token budget to control API costs. Enterprise contracts define per-seat budgets:
- Starter Seat: ~50K input + 15K output tokens/day (~5 sessions)
- Professional Seat: ~150K input + 45K output tokens/day (~15 sessions)
- Executive Seat: ~500K input + 150K output tokens/day (~50 sessions)

Track usage in Redis with atomic increments. Return a soft warning at 80% and hard-stop at 100%. Enterprise admins see aggregated usage in their dashboard.

### 2.5 Voice Architecture

Executives prefer voice — many will use this during commutes, between meetings, or while walking. Voice is a first-class input/output mode from MVP.

```
┌─────────────────────────────────────────────────┐
│              Voice Interaction Flow              │
│                                                  │
│  USER SPEAKS                                     │
│      │                                           │
│      ▼                                           │
│  ┌──────────────────────┐                        │
│  │ Apple Speech (STT)   │  On-device, real-time  │
│  │ SFSpeechRecognizer   │  Streaming recognition │
│  └──────────┬───────────┘                        │
│             │ Transcribed text                    │
│             ▼                                     │
│  ┌──────────────────────┐                        │
│  │ Voice Pre-Processor  │                        │
│  │                      │                        │
│  │ - Filler removal     │  "um", "uh", "like"    │
│  │ - Sentence boundary  │  Detect natural pauses  │
│  │ - Silence detection  │  Auto-send after 2s     │
│  └──────────┬───────────┘                        │
│             │ Cleaned text                        │
│             ▼                                     │
│  ┌──────────────────────┐                        │
│  │ Same LLM pipeline    │  Text and voice share   │
│  │ as text chat         │  the same backend       │
│  └──────────┬───────────┘                        │
│             │ AI response text                    │
│             ▼                                     │
│  ┌──────────────────────┐                        │
│  │ TTS Engine           │                        │
│  │                      │                        │
│  │ MVP: AVSpeechSynth   │  Free, on-device       │
│  │ v2: ElevenLabs API   │  Natural voice, $$$    │
│  │ v3: OpenAI TTS API   │  Good quality, cheaper │
│  └──────────┬───────────┘                        │
│             │ Audio stream                        │
│             ▼                                     │
│  USER HEARS RESPONSE                             │
└─────────────────────────────────────────────────┘
```

**Voice UI States:**
1. **Idle:** Microphone button visible; tap to start voice mode
2. **Listening:** Waveform animation; real-time transcription shown as subtitle
3. **Processing:** Transcription finalized; AI thinking indicator
4. **Speaking:** AI response plays as audio; text scrolls in sync
5. **Paused:** User can interrupt AI speech by tapping or speaking

**Voice-specific design decisions:**
- **On-device STT for MVP:** Apple Speech framework runs locally — no additional API cost, low latency, works offline for transcription. Quality is sufficient for clear English speech.
- **Hybrid TTS strategy:** AVSpeechSynthesizer is robotic but free and instant. Plan migration to ElevenLabs or OpenAI TTS once you validate voice adoption rates. Budget ~$0.015/1K characters for premium TTS.
- **Dual-mode sessions:** Users can switch between voice and text mid-session. All voice is transcribed and stored as text — the LLM never processes audio directly.
- **Audio recording opt-in:** Optionally store audio for human coach review (requires explicit consent). Stored in S3 with separate encryption key.
- **Background audio:** Support background audio playback so users can listen to AI responses while the app is backgrounded (AVAudioSession category: `.playback`).

**Voice cost impact (at 1,000 users, if 40% use voice):**

| Component | Cost Model | Est. Monthly |
|-----------|-----------|-------------|
| Apple Speech (STT) | Free (on-device) | $0 |
| AVSpeechSynthesizer (TTS MVP) | Free (on-device) | $0 |
| ElevenLabs TTS (Phase 2) | $0.30/1K chars | $1,200-2,400 |
| OpenAI TTS (Phase 2 alt) | $0.015/1K chars | $60-120 |

Recommendation: Ship MVP with on-device STT+TTS (zero marginal cost), then upgrade TTS to OpenAI TTS API as the cost-effective premium option.

---

## 3. Proprietary Coaching Methodology & AI Personas

### 3.1 Methodology Codification Process

The co-founder's coaching methodology is the product's core IP. Before building the AI coaching engine, this methodology must be extracted, structured, and encoded into prompt architecture. This is a **prerequisite to development** and should run in parallel with Phase 1 engineering.

**Codification Workflow:**

```
┌─────────────────────────────────────────────────────┐
│         Methodology Extraction (Weeks 1-3)          │
│                                                      │
│  3-4 recorded interview sessions with co-founder:    │
│                                                      │
│  Session 1: Core Philosophy & Framework              │
│  - What makes your approach different?               │
│  - Walk me through your first session with a new     │
│    executive. What do you always do?                  │
│  - What frameworks do you use most often?             │
│  - What do other coaches do that you think is wrong?  │
│                                                      │
│  Session 2: Scenario Decision Trees                  │
│  - When an exec says "I'm thinking of leaving",      │
│    what's your first move?                            │
│  - How do you handle someone who is defensive?        │
│  - When do you give direct advice vs ask questions?   │
│  - Walk me through a complex coaching arc (multi-     │
│    session progression)                               │
│                                                      │
│  Session 3: Career-Specific Playbooks                │
│  - Navigating promotion conversations                │
│  - Managing up / board communication                  │
│  - Team conflict resolution                           │
│  - First 90 days in a new role                        │
│  - Negotiation and compensation                       │
│                                                      │
│  Session 4: Boundaries & Escalation                  │
│  - When do you refer out?                             │
│  - What topics are outside your scope?                │
│  - How do you handle someone who needs therapy,       │
│    not coaching?                                      │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│         Methodology Structuring (Weeks 3-5)         │
│                                                      │
│  Transform recordings into structured documents:     │
│                                                      │
│  1. COACHING_PHILOSOPHY.md                           │
│     Core beliefs, principles, what makes it unique   │
│                                                      │
│  2. SESSION_FRAMEWORK.md                             │
│     How sessions open, flow, and close               │
│     Question banks organized by scenario             │
│                                                      │
│  3. SCENARIO_PLAYBOOKS.md                            │
│     Decision trees for 15-20 common executive        │
│     coaching scenarios                                │
│                                                      │
│  4. BOUNDARIES.md                                    │
│     What the AI should never do                      │
│     Escalation triggers specific to this methodology │
│                                                      │
│  5. MULTI_SESSION_ARCS.md                            │
│     How coaching evolves over weeks/months            │
│     When to revisit vs move forward                   │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│         Prompt Engineering (Weeks 5-8)              │
│                                                      │
│  Encode structured docs into system prompts:         │
│                                                      │
│  - Base methodology prompt (shared across personas)  │
│  - Persona-specific behavioral overlays              │
│  - Scenario-specific prompt fragments (injected      │
│    dynamically based on conversation context)         │
│  - Red-team testing: adversarial inputs to verify    │
│    the AI stays within methodology boundaries        │
│  - A/B testing prompt variants with co-founder       │
│    rating AI responses on a 1-5 fidelity scale       │
└─────────────────────────────────────────────────────┘
```

**Why this matters technically:** Generic coaching prompts ("You are a helpful executive coach") produce generic responses that any competitor can replicate. A codified methodology produces prompt instructions like: "When the user describes a conflict with their manager, ALWAYS start by asking what outcome they want before exploring the situation — never let them vent for more than 2 turns without redirecting to desired outcomes." This level of specificity creates measurably different AI behavior that maps to a proven coaching practice.

### 3.2 Persona Architecture

Each persona shares the **same proprietary methodology core** but varies in communication style. Think of it as one coaching brain with four different voices.

```
[PROMPT ASSEMBLY]
┌─────────────────────────────────────────┐
│  Layer 1: PROPRIETARY METHODOLOGY BASE  │  ← Same for all personas
│  (co-founder's framework, principles,   │
│   session structure, boundaries)         │
├─────────────────────────────────────────┤
│  Layer 2: PERSONA BEHAVIORAL OVERLAY    │  ← Varies per persona
│  (communication style, tone, question   │
│   patterns, advice directness)           │
├─────────────────────────────────────────┤
│  Layer 3: DYNAMIC CONTEXT INJECTION     │  ← Varies per session
│  (user profile, active goals, session   │
│   history, scenario playbook fragments)  │
├─────────────────────────────────────────┤
│  Layer 4: CONVERSATION HISTORY          │  ← Current session turns
│  (last N turns of this session)          │
└─────────────────────────────────────────┘
```

### 3.3 Persona Definitions

**1. Directive Coach ("The Strategist")**
- Style: Direct, structured, action-oriented
- Best for: Goal-setting, accountability, performance optimization, career trajectory planning
- Behavior: Gives clear recommendations, sets deadlines, follows up on commitments, challenges excuses directly
- Voice tone (for TTS): Confident, paced, business-like

**2. Facilitative Coach ("The Mirror")**
- Style: Socratic questioning, reflective
- Best for: Self-awareness, decision-making clarity, leadership identity, navigating ambiguity
- Behavior: Rarely gives answers; asks questions that surface the user's own insight; comfortable with silence
- Voice tone: Calm, measured, thoughtful pauses

**3. Supportive Coach ("The Ally")**
- Style: Empathetic, validating, encouraging
- Best for: Confidence building, navigating transitions (new role, layoff, re-org), imposter syndrome
- Behavior: Acknowledges emotions first, builds on strengths, gentle challenge after establishing trust
- Voice tone: Warm, reassuring, conversational

**4. Analytical Coach ("The Advisor")**
- Style: Data-driven, frameworks-heavy, systematic
- Best for: Strategic planning, stakeholder management, org design, board-level communication
- Behavior: Breaks problems into components, offers frameworks, requests data before recommending
- Voice tone: Precise, structured, slightly faster pace

### 3.4 System Prompt Structure Example (Directive Coach)

```
## YOUR IDENTITY
You are an executive career coach using the [METHODOLOGY_NAME] framework, 
developed from 15+ years of coaching C-suite leaders at major tech companies. 
Your coaching style is direct, strategic, and action-oriented.

## CORE METHODOLOGY (applies to all sessions)
[Injected from COACHING_PHILOSOPHY.md — co-founder's proprietary framework]

Key principles:
- [Principle 1 from codification: e.g., "Always establish desired outcome 
  before exploring the problem"]
- [Principle 2: e.g., "Challenge the narrative, not the person"]
- [Principle 3: e.g., "Every session ends with a commitment, not just 
  an insight"]
- [Additional principles from codification sessions]

## SESSION STRUCTURE
[Injected from SESSION_FRAMEWORK.md]

1. OPEN (1-2 exchanges): Check progress on prior commitments. 
   Ask: "[Co-founder's specific opening question]"
2. FOCUS: Identify today's topic. If unclear, use: 
   "[Co-founder's focusing question]"
3. EXPLORE: Apply relevant scenario playbook. Challenge assumptions 
   directly but respectfully.
4. ACTION: Close with specific next steps, owner, and timeline. 
   Use: "[Co-founder's commitment question]"
5. SUMMARIZE: 2-3 sentence recap of key insights and commitments.

## DIRECTIVE PERSONA OVERLAY
- Be direct. State observations as observations, not questions.
- When the user is circling, say: "Let me be direct — here's what 
  I'm hearing..." and summarize the core issue.
- Give specific recommendations when asked. Don't deflect with 
  "what do you think?" if they've clearly asked for your view.
- Set timelines: "By when will you do this?"

## SCENARIO PLAYBOOKS (dynamically injected based on topic detection)
[If topic = "conflict with manager"]: 
  [Injected from SCENARIO_PLAYBOOKS.md → manager_conflict section]
[If topic = "considering leaving"]:
  [Injected from SCENARIO_PLAYBOOKS.md → career_transition section]
[If topic = "new role first 90 days"]:
  [Injected from SCENARIO_PLAYBOOKS.md → new_role section]

## BOUNDARIES
- This is career and executive coaching. NOT therapy or mental health.
- Never diagnose conditions. Never recommend medication.
- If user discusses personal crisis, family trauma, or mental health 
  symptoms: acknowledge briefly, redirect to career framing, and 
  suggest connecting with a human coach or appropriate professional.
- Never provide legal or financial advice.
- Keep responses concise: 100-200 words per turn in text, 
  150-250 words in voice mode (slightly more for natural speech).
- Ask ONE question at a time.

## CONTEXT
- User profile: {user_profile}
- Active goals: {active_goals}
- Recent session summary: {recent_session_summary}
- Session number with this user: {session_count}
- Input mode: {text|voice}
```

---

## 4. Escalation System (Technical Design)

### 4.1 Escalation Architecture

The escalation system runs as an **async classifier** after each AI response, not blocking the conversation flow.

```
AI Response Generated
       │
       ▼ (async, non-blocking)
┌──────────────────────────────────┐
│  Escalation Classifier           │
│  Model: claude-haiku-4-5         │
│                                  │
│  Input:                          │
│  - Last 5 conversation turns     │
│  - User profile (tenure, tier)   │
│  - Session metadata              │
│                                  │
│  Output (structured JSON):       │
│  {                               │
│    "escalation_needed": bool,    │
│    "urgency": "low"|"med"|"high",│
│    "category": string,           │
│    "reasoning": string,          │
│    "suggested_coach_specialty":   │
│       string                     │
│  }                               │
└──────────┬───────────────────────┘
           │
     ┌─────▼──────┐
     │  Threshold  │
     │  Engine     │
     └─────┬──────┘
           │
    ┌──────┴───────────────────┐
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

### 4.2 Escalation Trigger Categories

| Category | Trigger Signal | Urgency | Action |
|----------|---------------|---------|--------|
| Complex career decision | Multi-stakeholder decision with political/strategic dimensions (reorg, board conflict, M&A) | Medium | Offer to schedule deep-dive with human coach |
| Repeated loops | Same topic surfaces 3+ times across sessions without progress | Medium | AI flags pattern, suggests human coach |
| User request | User explicitly asks for a human | High | Immediate booking flow |
| Topic boundary | Legal advice, financial planning, mental health symptoms, clinical territory | High | Decline topic + redirect appropriately |
| Personal crisis spillover | User discusses divorce, grief, burnout symptoms, or personal trauma beyond career impact | Medium | Acknowledge briefly, reframe to career impact, suggest human coach for deeper support |
| High-stakes negotiation | Compensation negotiation, exit package, co-founder disputes | Medium | Suggest human coach for role-play and strategy |
| Low engagement | User gives <5 word responses for 4+ turns | Low | AI adjusts approach; if persists, suggest human or reschedule |
| Org-political sensitivity | User describes situations involving HR investigations, legal exposure, whistleblowing | High | Do not coach on this; redirect to human coach + suggest legal counsel |

### 4.3 Escalation Classifier Prompt

```
Analyze this coaching conversation and determine if human coach 
escalation is needed.

Conversation (last 5 turns):
{conversation_turns}

User context:
- Sessions completed: {session_count}
- Current goals: {goals_summary}
- Subscription tier: {tier}

Respond in JSON only:
{
  "escalation_needed": true/false,
  "urgency": "low" | "medium" | "high",
  "category": "emotional_distress" | "complex_decision" | 
    "repeated_loop" | "user_request" | "topic_boundary" | 
    "low_engagement" | "none",
  "reasoning": "Brief explanation",
  "suggested_coach_specialty": "leadership" | "transitions" | 
    "communication" | "strategy" | "wellbeing" | null
}
```

---

## 5. Data Models

### 5.1 Core Database Schema (PostgreSQL)

```sql
-- Organizations (Enterprise customers)
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    domain VARCHAR(255),          -- e.g., "acme.com" for SSO matching
    subscription_plan VARCHAR(50) DEFAULT 'starter', -- starter|professional|enterprise
    total_seats INT NOT NULL,
    used_seats INT DEFAULT 0,
    billing_email VARCHAR(255),
    admin_user_id UUID,           -- primary admin
    settings JSONB DEFAULT '{}',  -- org-level config (allowed personas, etc.)
    contract_start DATE,
    contract_end DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES organizations(id),  -- NULL for individual users
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255),
    title VARCHAR(255),           -- e.g., "VP Engineering"
    company VARCHAR(255),
    role VARCHAR(50) DEFAULT 'member', -- member|admin|org_admin
    seat_tier VARCHAR(50) DEFAULT 'professional', -- starter|professional|executive
    preferred_persona VARCHAR(50) DEFAULT 'directive',
    preferred_input_mode VARCHAR(10) DEFAULT 'text', -- text|voice
    onboarding_completed BOOLEAN DEFAULT FALSE,
    onboarding_assessment JSONB,  -- stored assessment results
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_org ON users(org_id);

-- Coaching Sessions
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    org_id UUID REFERENCES organizations(id),  -- denormalized for enterprise reporting
    session_type VARCHAR(50),     -- ai_coaching|human_coaching|check_in
    input_mode VARCHAR(10),       -- text|voice|mixed
    persona VARCHAR(50),          -- directive|facilitative|supportive|analytical
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    duration_seconds INT,
    summary TEXT,                 -- AI-generated session summary
    action_items JSONB,           -- [{text, due_date, completed}]
    escalation_triggered BOOLEAN DEFAULT FALSE,
    escalation_category VARCHAR(50),
    token_usage_input INT,
    token_usage_output INT,
    tts_characters INT DEFAULT 0  -- for voice cost tracking
);

-- Chat Messages
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES sessions(id),
    role VARCHAR(20) NOT NULL,    -- user|assistant|system
    content TEXT NOT NULL,
    input_mode VARCHAR(10),       -- text|voice (how user sent this message)
    audio_s3_key VARCHAR(500),    -- S3 path to audio recording (if voice + opt-in)
    metadata JSONB,               -- escalation flags, detected scenario tags
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Goals
CREATE TABLE goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    org_id UUID REFERENCES organizations(id),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    category VARCHAR(100),        -- career_growth|leadership|communication|strategy|stakeholder_mgmt
    status VARCHAR(50) DEFAULT 'active', -- active|completed|paused|abandoned
    target_date DATE,
    progress INT DEFAULT 0,       -- 0-100
    milestones JSONB,             -- [{title, completed, date}]
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Human Coaches
CREATE TABLE coaches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    specialties TEXT[],           -- ARRAY of specialty tags
    bio TEXT,
    years_experience INT,
    certifications TEXT[],
    hourly_rate DECIMAL(10,2),
    availability JSONB,           -- weekly schedule slots
    max_clients INT DEFAULT 20,
    active_clients INT DEFAULT 0,
    rating DECIMAL(3,2),
    is_active BOOLEAN DEFAULT TRUE
);

-- Human Coach Bookings
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    coach_id UUID REFERENCES coaches(id),
    session_id UUID REFERENCES sessions(id),
    scheduled_at TIMESTAMPTZ NOT NULL,
    duration_minutes INT DEFAULT 30,
    status VARCHAR(50) DEFAULT 'scheduled', -- scheduled|completed|cancelled|no_show
    escalation_context TEXT,      -- AI summary of why escalation was triggered
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Conversation Embeddings (for RAG)
CREATE TABLE session_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES sessions(id),
    user_id UUID REFERENCES users(id),
    chunk_text TEXT NOT NULL,
    embedding vector(1536),       -- pgvector, dimensionality matches embedding model
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON session_embeddings 
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Enterprise Reporting View (for org admin dashboard)
CREATE VIEW org_coaching_summary AS
SELECT 
    o.id AS org_id,
    o.name AS org_name,
    COUNT(DISTINCT u.id) AS active_users,
    COUNT(DISTINCT s.id) AS total_sessions,
    COUNT(DISTINCT s.id) FILTER (WHERE s.started_at > NOW() - INTERVAL '30 days') AS sessions_last_30d,
    AVG(s.duration_seconds) AS avg_session_duration,
    COUNT(DISTINCT g.id) FILTER (WHERE g.status = 'completed') AS goals_completed,
    COUNT(DISTINCT s.id) FILTER (WHERE s.escalation_triggered) AS escalations,
    COUNT(DISTINCT s.id) FILTER (WHERE s.input_mode = 'voice') AS voice_sessions,
    SUM(s.token_usage_input + s.token_usage_output) AS total_tokens_used
FROM organizations o
JOIN users u ON u.org_id = o.id
LEFT JOIN sessions s ON s.user_id = u.id
LEFT JOIN goals g ON g.user_id = u.id
GROUP BY o.id, o.name;
```

### 5.2 Redis Key Structure

```
# Token budget tracking (per-seat)
token_budget:{user_id}:daily:input    → INT (atomic incr)
token_budget:{user_id}:daily:output   → INT (atomic incr)
token_budget:{user_id}:daily:reset_at → TIMESTAMP (TTL-based expiry)

# TTS character budget (per-seat, for Phase 2 premium TTS)
tts_budget:{user_id}:daily:chars      → INT (atomic incr)

# Org-level usage aggregation
org_usage:{org_id}:monthly:tokens     → INT
org_usage:{org_id}:monthly:sessions   → INT

# Active session state
session:{session_id}:state            → JSON {turns, persona, context_window, input_mode}

# Rate limiting
ratelimit:{user_id}:messages          → INT (sliding window counter)

# Coach availability cache
coach:{coach_id}:slots                → SORTED SET (available time slots)
```

---

## 6. Key User Flows

### 6.1 Onboarding Flow

```
Enterprise Admin sends invite (email or SSO domain allowlist)
    │
    ▼
User receives invite → Downloads app
    │
    ▼
Apple Sign-In / SSO (if enterprise has SAML configured)
    │
    ▼
Welcome: "Your organization has provided you with executive coaching"
    │
    ▼
Leadership Assessment (5-7 questions, career-focused)
  - Current role, tenure, and team size
  - Top career goal for the next 12 months
  - Biggest leadership challenge right now
  - Past coaching experience (if any)
  - Preferred communication style (select from examples)
  - Top 3 development areas: career growth, stakeholder management,
    communication, strategic thinking, team leadership, executive presence,
    decision-making, delegation
    │
    ▼
Input Mode Preference
  - "How do you prefer to coach?" → Text / Voice / Both
  - Brief demo of voice mode (play sample exchange)
    │
    ▼
Persona Recommendation
  - AI suggests best-fit persona based on assessment
  - User can preview each persona style with sample exchange
  - User selects (can change anytime)
    │
    ▼
First Goal Setup
  - Guided goal creation (title, description, target date)
  - AI suggests milestones based on goal and role context
    │
    ▼
First AI Coaching Session (auto-start, in preferred input mode)
  - "Let's dive in. Tell me about [their stated challenge]..."
```

### 6.2 Daily AI Coaching Session Flow

```
User opens app → "Ready for a session?" prompt
    │
    ▼
AI loads context:
  - User profile + persona
  - Active goals + progress
  - Last session summary + open action items
  - RAG: relevant past session snippets
    │
    ▼
Session begins (streaming chat UI)
  - AI opens with follow-up on prior commitments
  - User drives topic
  - AI coaches using persona methodology
  - Session targets 5-10 minutes (soft prompt to wrap up)
    │
    ▼
Session close:
  - AI generates summary
  - AI extracts action items (structured)
  - Goal progress auto-updated if relevant
  - Escalation classifier runs async
    │
    ▼
Post-session:
  - Summary card displayed
  - Action items added to dashboard
  - (If escalation triggered) → soft prompt to book human coach
```

### 6.3 Human Coach Escalation Flow

```
Escalation triggered (any trigger category)
    │
    ├── Soft (low/medium urgency):
    │     AI says: "This is a great topic to explore deeper. 
    │     Would you like to schedule a session with a human coach 
    │     who specializes in [specialty]?"
    │     │
    │     ▼
    │   User taps "Book Coach" → Coach matching → Calendar picker
    │     │
    │     ▼
    │   Pre-session brief auto-generated for human coach:
    │   - User profile summary
    │   - Relevant session history
    │   - Escalation context
    │   - Active goals
    │
    └── Urgent (high urgency / crisis):
          Push notification: "We'd like to connect you with 
          a coach. Tap to schedule."
          │
          ▼
        Priority booking queue (next available slot)
```

---

## 7. iOS App Structure

### 7.1 Navigation Architecture

```
TabView (4 tabs — Member View)
├── 🏠 Home (Today)
│   ├── Daily check-in prompt (text or voice)
│   ├── Active session (if in progress)
│   ├── Action items due today
│   └── Streak / engagement stats
│
├── 💬 Sessions
│   ├── Start new AI session (text or voice toggle)
│   ├── Session history (grouped by week)
│   ├── Session detail → transcript + summary + action items
│   └── Upcoming human coach sessions
│
├── 🎯 Goals
│   ├── Active goals list (progress bars)
│   ├── Goal detail → milestones, related sessions, analytics
│   ├── Add new goal
│   └── Completed goals archive
│
└── 👤 Profile
    ├── Account settings
    ├── Coaching persona selection
    ├── Input preference (voice / text default)
    ├── Voice settings (TTS voice, speed)
    ├── Coach preferences
    └── Data export / privacy

Enterprise Admin View (separate tab bar, role-gated)
├── 📊 Dashboard
│   ├── Org-wide engagement metrics
│   ├── Sessions per user (anonymized or named, configurable)
│   ├── Goal completion rates across team
│   ├── Token/seat usage vs allocation
│   └── Escalation frequency and categories
│
├── 👥 Team Management
│   ├── Add/remove seat assignments
│   ├── Invite users via email or SSO domain
│   ├── Set per-user seat tier
│   └── View individual usage (if org policy allows)
│
└── ⚙️ Settings
    ├── SSO configuration
    ├── Allowed personas (restrict which styles are available)
    ├── Data retention policy
    ├── Billing and invoicing
    └── Coach network preferences
```

### 7.2 Chat UI Specifications

**Dual-Mode Interface:**
The chat screen supports both text and voice as primary input, switchable via a toggle. The UI adapts based on mode.

**Text Mode:**
- Streaming display: Token-by-token rendering using SSE/WebSocket
- Typing indicator: Animated dots while AI generates
- Message bubbles: User (right, brand color), AI (left, neutral), system (center, subtle)
- Quick actions: Thumbs up/down on AI messages for quality data collection
- Session timer: Subtle top-bar indicator showing session duration
- Escalation CTA: When triggered, inline card with coach booking button

**Voice Mode:**
- Full-screen voice UI: Large waveform visualization, minimal text
- Real-time transcription: User's speech appears as live subtitle text
- AI response: Plays as audio with synchronized text scroll
- Interrupt: Tap anywhere or start speaking to interrupt AI playback
- Visual feedback states: Listening (pulsing mic) → Processing (thinking animation) → Speaking (waveform)
- Mode switch: Floating button to toggle to text mid-session
- Session controls: Pause, end session, switch to text — accessible during voice playback

**Shared:**
- Session context banner: Shows current goal context and session number
- Action item extraction: AI-identified commitments highlighted inline with "Add to goals" tap target

---

## 8. Security & Privacy

### 8.1 Data Protection

- **Encryption at rest:** AES-256 for all stored data (RDS encryption, S3 SSE)
- **Encryption in transit:** TLS 1.3 for all API communication
- **Auth tokens:** Short-lived JWTs (15 min) + refresh tokens (30 days) stored in iOS Keychain
- **PII handling:** User names and company names excluded from LLM training data; use Anthropic API's data retention opt-out
- **Session transcripts:** Encrypted in S3; user can delete anytime (hard delete)

### 8.2 Compliance Considerations

- **SOC 2 Type II:** Required for enterprise sales — use compliant cloud infrastructure from day 1. Budget 3-6 months for initial certification.
- **GDPR:** Data export, right to deletion, consent management. Required if selling to European enterprises.
- **CCPA:** Privacy notice, opt-out mechanisms. Required for California-based enterprise customers.
- **HIPAA: NOT APPLICABLE.** This is career and executive coaching, not mental health services or therapy. The app explicitly does not diagnose conditions, prescribe treatments, or provide clinical interventions. This decision eliminates BAA requirements, specialized hosting, and clinical data handling overhead. Ensure marketing and in-app language consistently frames the product as "professional development" and "career coaching."
- **Enterprise SSO:** Support SAML 2.0 / OIDC for enterprise single sign-on (Okta, Azure AD, Google Workspace). Required for enterprise deals >50 seats.
- **Data residency:** Be prepared for enterprise customers requesting data stored in specific regions (EU, US). Use AWS region selection at the org level.
- **Voice recording consent:** If storing audio recordings, implement two-party consent flows. Some jurisdictions require all-party notification. Default to NOT storing audio; only store transcribed text unless user explicitly opts in.

---

## 9. Analytics & Success Metrics

### 9.1 Product Metrics (Mixpanel/Amplitude)

| Metric | Target | Measurement |
|--------|--------|-------------|
| DAU/MAU ratio | >30% | Daily active users / monthly active users |
| Avg sessions per week | ≥3 | Sessions started per active user |
| Session completion rate | >80% | Sessions with proper close vs abandoned |
| Voice adoption rate | >35% | % of sessions using voice input |
| Goal completion rate | >40% | Goals marked complete within target date |
| Escalation acceptance rate | >50% | Users who book human coach when suggested |
| Org activation rate | >70% | % of assigned seats with ≥1 session in first 30 days |
| Seat utilization | >60% | Monthly active seats / total purchased seats |
| NPS | >50 | Quarterly survey |
| Net revenue retention | >110% | Annual expansion vs churn (enterprise) |
| Logo churn | <10% annual | Enterprise customer cancellations |

### 9.2 AI Quality Metrics (Internal)

| Metric | Measurement |
|--------|-------------|
| Response helpfulness | Thumbs up/down ratio per persona |
| Escalation precision | % of escalations user found appropriate (survey) |
| Goal extraction accuracy | Manual audit sample: did AI correctly identify action items? |
| Context relevance | RAG retrieval quality spot-checks |
| Persona consistency | LLM-as-judge evaluation on random sample |

---

## 10. MVP Scope & Phasing

### Pre-Phase: Methodology Codification (Weeks 1-8, parallel with Phase 1 engineering)

**Deliverables (co-founder + prompt engineer):**
- 4 recorded interview sessions with co-founder (see Section 3.1)
- COACHING_PHILOSOPHY.md — core principles and what makes this approach unique
- SESSION_FRAMEWORK.md — session structure, opening/closing patterns, question banks
- SCENARIO_PLAYBOOKS.md — decision trees for 15-20 common executive scenarios
- BOUNDARIES.md — what the AI should never do, escalation triggers
- MULTI_SESSION_ARCS.md — how coaching evolves over time
- Base system prompt + 2 persona overlays (Directive, Supportive), tested and rated by co-founder
- Prompt fidelity benchmark: co-founder rates 50 AI responses on 1-5 "sounds like me" scale; target ≥3.5 avg

### Phase 1 — MVP (Months 1-5)

**Build:**
- iOS app with SwiftUI: onboarding, chat (text + voice), goals, profile
- 2 coaching personas (Directive + Supportive) using proprietary methodology prompts
- Voice input via Apple Speech (on-device STT) + AVSpeechSynthesizer (on-device TTS)
- Dual-mode chat UI: text and voice with seamless switching
- Claude Sonnet integration with streaming
- Basic context management (last session summary, active goals, user profile)
- Goal CRUD with manual progress updates
- Manual escalation only ("I want to talk to a human" → external Calendly link)
- Supabase backend (auth + Postgres + storage)
- Basic enterprise: org table, seat assignment, admin can invite users via email
- Apple Sign-In + email/password auth (SSO in Phase 2)
- Basic analytics (Mixpanel)

**Skip for now:**
- RAG / conversation embeddings
- Automated escalation classifier
- Human coach network / matching / in-app scheduling
- Enterprise SSO (SAML/OIDC)
- Enterprise admin dashboard (admin manages via simple list view)
- Premium TTS (ElevenLabs/OpenAI)

### Phase 2 — Intelligence + Enterprise (Months 6-9)

**Add:**
- All 4 coaching personas with proprietary methodology
- Automated escalation classifier (Haiku-based)
- RAG with pgvector (pull relevant past sessions into context)
- Scenario playbook dynamic injection (detect topic → load relevant playbook into prompt)
- Human coach profiles + booking flow (integrate Calendly API initially)
- AI-generated session summaries + action item extraction
- Push notifications (session reminders, action item due dates)
- Token budget tracking and enforcement per seat tier
- Enterprise SSO (SAML 2.0 / OIDC via Auth0)
- Enterprise admin dashboard (engagement metrics, seat management, usage reporting)
- Upgrade TTS to OpenAI TTS API for natural voice quality

### Phase 3 — Scale (Months 10-15)

**Add:**
- Coach matching algorithm
- In-app video calling (Daily.co or Twilio) for human coach sessions
- Coach-facing portal (session briefs, client notes, escalation context)
- Advanced enterprise: data residency options, custom data retention policies, audit logs
- Slack/Teams integration for nudges and session reminders
- White-label capability for coaching firms
- API for third-party HR platform integrations (Workday, BambooHR)
- Multi-session arc tracking (AI tracks coaching progression over months, adjusts approach)

---

## 11. Cost Estimation (Monthly, at 1,000 Active Seats across Enterprise Customers)

| Item | Estimated Cost |
|------|---------------|
| Claude API — Sonnet (~3 sessions/user/day) | $2,000-4,000 |
| Claude API — Haiku (escalation classifier) | $100-200 |
| Apple Speech STT (on-device) | $0 |
| TTS — AVSpeechSynthesizer MVP (on-device) | $0 |
| TTS — OpenAI TTS Phase 2 (40% voice adoption) | $60-120 |
| Supabase Pro | $25 |
| AWS infrastructure (ECS, RDS, Redis, S3) | $500-1,000 |
| Auth0 (enterprise SSO) | $130 (B2B Starter) |
| Apple Developer Program | $8/mo (annual) |
| Mixpanel | $0 (free tier to start) |
| Firebase (push notifications) | $0 (free tier) |
| **Total infra** | **~$3,000-5,500/mo** |

**Enterprise pricing model:**

| Tier | Per-seat/month | Includes |
|------|---------------|----------|
| Starter (10-49 seats) | $79/seat | AI coaching (2 personas), basic goals, text + voice |
| Professional (50-199 seats) | $149/seat | All personas, human coach sessions (1/mo/seat), admin dashboard |
| Enterprise (200+ seats) | Custom | All features, SSO, dedicated CSM, custom methodology overlay, SLA |

**Unit economics at 100 seats (Professional tier):**
Revenue: 100 × $149 = $14,900/mo
Infra cost: ~$800/mo (scaled down from 1K estimate)
Gross margin: ~95% on AI coaching; human coach sessions reduce margin to ~60-70% blended

**Key insight:** Enterprise B2B2C pricing is per-seat, not per-user-self-serve. This means predictable revenue, higher contract values, and the ability to negotiate annual contracts upfront.

---

## 12. Decisions Made

| Decision | Resolution | Impact |
|----------|-----------|--------|
| Coaching methodology | Codifying co-founder's proprietary methodology | Core IP moat; requires 8-week codification pre-phase |
| Market positioning | Career & executive coaching (NOT mental health) | No HIPAA; simplifies compliance; sharpens marketing |
| GTM strategy | Enterprise-first (B2B2C) | Per-seat pricing; longer sales cycle but higher ACV |
| Input modality | Voice + text from MVP | Requires Apple Speech + TTS integration in Phase 1 |

## 13. Remaining Open Questions

1. **Human coach supply model:** Build own vetted coach network vs partner with existing platform (e.g., CoachHub API, BetterUp partner program)? Own network = higher quality control + margins but slower to scale. Partner = faster launch but less control and margin compression. **Recommendation:** Start with 5-10 hand-picked coaches from co-founder's network for pilot, then decide build vs partner based on demand volume.

2. **Methodology naming and branding:** Does the co-founder's coaching approach have a name? If not, create one — it becomes a marketing asset ("Powered by the [Name] Method"). This matters for enterprise sales positioning.

3. **Enterprise pilot strategy:** Which 3-5 companies will be the design partners? Ideal: companies where co-founder has existing relationships, 50-200 person leadership teams, tech-forward culture willing to adopt AI coaching. Lock in 2-3 before writing production code.

4. **Data isolation requirements:** Will enterprise customers require dedicated database instances (single-tenant) or is multi-tenant with row-level security sufficient? This affects architecture cost significantly. Most mid-market enterprises accept multi-tenant with SOC 2; large enterprises may demand single-tenant.

5. **Coach-AI continuity:** When a user escalates to a human coach, should the human coach use the app to take notes that feed back into the AI's context? This is a powerful differentiator but requires building a coach-facing interface in Phase 2.

6. **Android timeline:** Enterprise customers will eventually need Android. Plan for cross-platform (Kotlin Multiplatform, Flutter) or maintain two native codebases? Decision affects team hiring.
