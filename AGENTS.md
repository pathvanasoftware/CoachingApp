# Ascendra - AI Coaching App

## Goal

Build and maintain **Ascendra** — an iOS executive coaching app by **Pathvana** with a FastAPI backend on Railway. All persistence layers now use PostgreSQL for durability. Redis provides idempotency caching for LLM responses.

---

## Instructions

- App name: **Ascendra**, Company: **Pathvana**, Bundle ID: `com.pathvana.ascendra`
- Always build and verify with `xcodebuild -project CoachingApp.xcodeproj -scheme CoachingApp -sdk iphonesimulator build` before committing iOS changes
- Always commit and push after changes
- Default userId is `"test-user-001"`
- Backend is FastAPI on Railway at `coachingapp-backend-production.up.railway.app`
- iOS working directory: `/Users/jianping/projects/CoachingApp`
- Backend working directory: `/Users/jianping/projects/CoachingApp/backend`
- Use real services in production; mock only in DEBUG with explicit toggle
- Redis is configured on Railway for idempotency caching
- PostgreSQL is configured on Railway for auth and profile persistence

---

## Discoveries

### Database Architecture (Current)
- **Auth persistence**: PostgreSQL on Railway
  - `users` table: id, email, password_hash, full_name, organization_id, seat_tier, preferred_persona, preferred_input_mode, has_completed_onboarding, google_id, apple_id, created_at, updated_at
  - Connection via `DATABASE_URL` environment variable
  - Uses `psycopg[binary]` driver
- **Session state**: PostgreSQL on Railway (migrated from filesystem)
  - `coaching_profiles` table: user_id (PK), profile_json (JSONB), updated_at
  - Stores goals, patterns, emotion_timeline, session_state, last_topics
  - Toggle via `PROFILE_STORE=postgres` (default when DATABASE_URL is set)
- **Idempotency cache**: Redis on Railway (keyed by requestId)

### Cache System Design (Implemented)
- **Idempotency cache** keyed by `requestId` prevents duplicate LLM calls and double session-state mutation on retries/reconnects
- **Single-flight locking** (`SET NX EX`) prevents concurrent duplicates from both calling LLM before cache write
- **Follower behavior**: `/chat` returns `202` after short wait; `/chat-stream` polls with SSE keepalive then re-streams cached result
- **State mutation fingerprint**: `pre_state_rev`/`post_state_rev` stored in cached record; cache hits must not increment rev
- Redis service provisioned on Railway with internal URL wired to backend via `REDIS_URL` env var

### Coaching Engine Behavior
- **Stage routing** is now deterministic based on signal extraction, not keyword matching
- **ConversationSignals** dataclass extracts: stakeholder, outcome, example, timeframe, constraint, leaning, topic_signature
- **Stage state machine**: `diagnose → reframe → options → commit` with rollback on topic shift
- **Diagnose contract**: exactly one question, no frameworks/advice, enforced via `_enforce_diagnose_contract()`
- Stage persisted in `profile["session_state"][session_id]` with `state_rev` for correctness

### Railway Deployment
- GitHub Actions workflow fixed: uses `RAILWAY_API_TOKEN` env var, runs from repo root
- `/health` endpoint returns `git_sha`, `git_sha_short`, `deployed_at` for deploy verification
- **Active Services**:
  - `CoachingApp-Backend` (service ID: `01ab53f3-4c3c-4c0e-8733-6ee949141da2`)
  - `Redis` (service ID: `34baa38b-00bc-4adb-822e-8635645cd032`)
  - `Postgres` (service ID: `f9b714e9-0c08-47c1-bb42-97e2443a8560`)

### Other Fixes
- Coach Mode selection now visible with checkmark + "Selected" label + highlighted row
- Coach Mode badge in chat header is tappable, opens quick settings sheet
- Google auth cancellation handled cleanly (no false error on user cancel)
- Apple Sign-In implemented with nonce-based verification
- Session openings are now instant local templates (no LLM call for greeting)

---

## Accomplished

### Completed ✅
- **PostgreSQL migration for auth** - SQLite replaced with PostgreSQL on Railway
- **PostgreSQL migration for profiles** - Filesystem JSON replaced with PostgreSQL for session state
- **Deterministic stage router** with signal extraction + session-aware state machine
- **Diagnose contract guardrail** (zero advice, exactly one question, rewrite on violation)
- **Request-id idempotency cache** with single-flight lock, 202 follower behavior, poll endpoint
- **Redis setup on Railway** with backend env vars configured
- **Coach Mode UI fixes** (selection visibility, header badge, tappable picker)
- **Apple Sign-In** with nonce verification (client + server)
- **Google auth cancellation** handling
- **Instant local session openings** (no LLM for greeting)
- **Health endpoint version stamp** (`git_sha`, `deployed_at`, `profile_backend`)
- **Backend tests**: 187 passed
- **iOS build**: passing
- **Railway service cleanup**: Removed duplicate Postgres and orphaned Redis services

### Minor Cleanup Remaining
- `/health` `git_sha` shows "unknown" in Railway env (CI-generated `build_info.json` would fix)

---

## Relevant Files / Directories

```
CoachingApp/
├── CoachingApp.xcodeproj/project.pbxproj
├── CoachingApp/
│   ├── App/
│   │   ├── AppState.swift                           # selectedCoachingStyle persisted to UserDefaults
│   │   ├── CoachingAppApp.swift
│   │   └── ServiceContainer.swift
│   ├── Features/
│   │   ├── Auth/
│   │   │   ├── SignInView.swift                     # Google/Apple buttons, loading state
│   │   │   └── AuthViewModel.swift                  # Apple nonce, cancellation handling
│   │   ├── Profile/
│   │   │   └── ProfileView.swift                    # Coach Mode picker with visual selection
│   │   └── Sessions/
│   │       └── Chat/
│   │           ├── ChatView.swift                   # Mode badge in header, tappable sheet
│   │           └── ChatViewModel.swift              # Local openings, requestId propagation
│   ├── Models/
│   │   └── CoachingPersona.swift                    # CoachingStyle enum
│   └── Services/
│       ├── Chat/
│       │   ├── StreamingService.swift               # requestId added to streaming payload
│       │   └── ChatHistoryStorage.swift
│       └── MockServices/
│           └── MockChatService.swift                # requestId param added to protocol

backend/
├── main.py
├── requirements.txt                                 # psycopg[binary]>=3.2.0, pyjwt[crypto]>=2.8.0
├── railway.toml
├── .env.example                                     # DATABASE_URL, REDIS_URL, PROFILE_STORE
├── app/
│   ├── routers/
│   │   ├── auth.py                                  # PostgreSQL-backed UserService
│   │   ├── chat.py                                  # Idempotency cache, single-flight lock, /result endpoint
│   │   └── health.py                                # git_sha, deployed_at, profile_backend
│   └── services/
│       ├── auth.py                                  # UserService with PostgreSQL (psycopg)
│       ├── cache.py                                 # CacheBackend, InMemoryCache, RedisCache
│       ├── llm.py                                   # CoachingRequest.request_id added
│       ├── llm_claude.py                            # ConversationSignals, stage router, state_rev
│       ├── memory_store.py                          # profile/session_state persistence (PostgreSQL)
│       ├── profile_store.py                         # NEW — ProfileStore for PostgreSQL
│       └── auth.py                                  # verify_apple_token with nonce
└── tests/
    ├── test_llm_async.py                            # Stage progression, diagnose contract tests
    └── test_routers.py                              # Cache hit, 202 follower tests

.github/workflows/
├── backend-tests.yml                                # PostgreSQL service container, DATABASE_URL
└── backend-deploy-railway.yml                       # RAILWAY_API_TOKEN, runs from root
```

---

## Next Actions

1. Consider adding CI-generated `build_info.json` so `/health` reports exact `git_sha`
2. Add app-level encryption for cached entries if compliance requires it
