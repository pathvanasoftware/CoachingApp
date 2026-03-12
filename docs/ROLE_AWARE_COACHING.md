# Role-Aware Coaching Design Document

## 1. Problem Statement

Users select their role level during onboarding (Individual Contributor, Manager, Director, VP/SVP, C-Suite/Founder), but this information is **never used** in subsequent coaching conversations. This creates a disconnected user experience where users invest time in onboarding decisions that don't impact their coaching experience.

### Current State

```
Onboarding Flow:
┌─────────────────────────────────────────────────────────────┐
│ "What best describes your current role?"                    │
│ ○ Individual Contributor / Senior IC                       │
│ ○ Manager / Team Lead                                       │
│ ○ Director / Senior Manager                                │
│ ○ VP / SVP                                                  │
│ ○ C-Suite / Founder                                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │  Answer saved to OnboardingData.userRole │
        │  BUT NEVER USED AGAIN ❌                │
        └─────────────────────────────────────────┘
```

### Root Cause Analysis

1. **Frontend**: `OnboardingViewModel` stores `userRole` but never persists it to backend
2. **Backend**: User schema (`app/services/auth.py`) lacks `role_level` field
3. **API**: `ChatStreamRequest` doesn't include role context
4. **Prompt**: System prompt doesn't receive role-aware context

### Impact

- Users perceive onboarding questions as meaningless
- Coaching responses are generic and not role-tailored
- Missed opportunity for more relevant coaching

---

## 2. Goals

1. **Persist role level** to backend profile storage (not just local state)
2. **Inject role context** into all coaching responses via SSE stream path
3. **Maintain backward compatibility** for existing users
4. **Allow role updates** via settings
5. **Respect existing guardrails** (stage routing, inquiry-first contract)

---

## 3. Design Overview

### 3.1 Role Level Taxonomy

```swift
enum RoleLevel: String, Codable, CaseIterable {
    case individualContributor = "individual_contributor"
    case manager = "manager"
    case director = "director"
    case vp = "vp"
    case cSuite = "c_suite"

    var displayName: String {
        switch self {
        case .individualContributor: return "Individual Contributor"
        case .manager: return "Manager"
        case .director: return "Director"
        case .vp: return "VP / SVP"
        case .cSuite: return "C-Suite / Founder"
        }
    }

    var coachingFocus: [String] {
        switch self {
        case .individualContributor:
            return ["Personal impact", "Skill development", "Visibility", "Influence without authority"]
        case .manager:
            return ["Team performance", "Direct reports", "Execution", "Managing up"]
        case .director:
            return ["Cross-functional alignment", "Manager-of-managers", "Strategic initiatives"]
        case .vp:
            return ["Business outcomes", "P&L responsibility", "Org strategy", "Executive presence"]
        case .cSuite:
            return ["Company strategy", "Board relations", "Industry positioning", "Culture & values"]
        }
    }
}
```

### 3.2 Data Flow (Corrected)

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                              ONBOARDING                                        │
├────────────────────────────────────────────────────────────────────────────────┤
│  User selects role → OnboardingData.userRole → API Call → ProfileStore       │
│                                                                   │           │
│                                    ┌────────────────────────────────┘           │
│                                    ▼                                            │
│                       coaching_profiles table (role_level field)               │
└────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                    SESSION START /auth/me REFRESH                               │
├────────────────────────────────────────────────────────────────────────────────┤
│  GET /auth/me returns user with role_level → AppState.userRoleLevel           │
└────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                         CHAT STREAMING (SSE)                                   │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  POST /api/chat/chat-stream                                                   │
│  {                                                                             │
│    "sessionId": "...",                                                         │
│    "message": "...",                                                           │
│    "persona": "...",                                                           │
│    "coachingStyle": "...",                                                     │
│    "userRoleLevel": "manager"  ← NEW FIELD                                     │
│  }                                                                             │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                         PROMPT GENERATION                                      │
├────────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  System prompt includes:                                                       │
│  "User role level: manager. Focus on: team performance, direct reports,        │
│   execution, and managing up. Adjust question depth and scope accordingly."   │
│                                                                                │
│  NOTE: Role context is ADDITIONAL to existing stage routing and               │
│        inquiry-first guardrails. It does NOT override them.                   │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Backend Changes

### 4.1 Database Schema (No Alembic - use ProfileStore._ensure_db pattern)

**File: `app/services/profile_store.py`**

Add `role_level` to the `coaching_profiles` schema:

```python
# app/services/profile_store.py

class ProfileStore:
    def _ensure_db(self):
        with psycopg.connect(self.database_url) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS coaching_profiles (
                        user_id TEXT PRIMARY KEY,
                        profile_json JSONB NOT NULL,
                        role_level TEXT DEFAULT NULL,
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
                    )
                """)
                # Add column if table exists (migration path)
                cur.execute("""
                    DO $$
                    BEGIN
                        IF NOT EXISTS (
                            SELECT 1 FROM information_schema.columns
                            WHERE table_name = 'coaching_profiles' AND column_name = 'role_level'
                        ) THEN
                            ALTER TABLE coaching_profiles ADD COLUMN role_level TEXT;
                        END IF;
                    END $$;
                """)
            conn.commit()

    def save_profile(self, user_id: str, profile: Dict[str, Any], role_level: Optional[str] = None) -> None:
        now = datetime.now(timezone.utc)
        with self._get_conn() as conn:
            with conn.cursor() as cur:
                if role_level:
                    # Merge role_level into profile_json and set column
                    profile_with_role = {**profile, "role_level": role_level}
                    cur.execute(
                        """INSERT INTO coaching_profiles (user_id, profile_json, role_level, updated_at)
                           VALUES (%s, %s, %s, %s)
                           ON CONFLICT (user_id)
                           DO UPDATE SET profile_json = %s, role_level = %s, updated_at = %s""",
                        (user_id, json.dumps(profile_with_role), role_level, now,
                         json.dumps(profile_with_role), role_level, now),
                    )
                else:
                    # Existing behavior
                    cur.execute(
                        """INSERT INTO coaching_profiles (user_id, profile_json, updated_at)
                           VALUES (%s, %s, %s)
                           ON CONFLICT (user_id)
                           DO UPDATE SET profile_json = %s, updated_at = %s""",
                        (user_id, json.dumps(profile), now, json.dumps(profile), now),
                    )
            conn.commit()

    def get_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        with self._get_conn() as conn:
            with conn.cursor(row_factory=dict_row) as cur:
                cur.execute(
                    "SELECT profile_json, role_level FROM coaching_profiles WHERE user_id = %s",
                    (user_id,),
                )
                row = cur.fetchone()
        if not row:
            return None
        profile = row["profile_json"]
        # Merge role_level if set
        if row.get("role_level"):
            profile = {**profile, "role_level": row["role_level"]}
        return profile

    def update_role_level(self, user_id: str, role_level: str) -> None:
        """Update only the role_level field."""
        now = datetime.now(timezone.utc)
        with self._get_conn() as conn:
            with conn.cursor() as cur:
                # Update both column and JSON for consistency
                cur.execute("""
                    UPDATE coaching_profiles
                    SET role_level = %s,
                        profile_json = jsonb_set(
                            COALESCE(profile_json, '{}'::jsonb),
                            '{role_level}',
                            %s::jsonb
                        ),
                        updated_at = %s
                    WHERE user_id = %s
                """, (role_level, json.dumps(role_level), now, user_id))
            conn.commit()
```

### 4.2 Add Update Role Level Endpoint

**File: `app/routers/auth.py`** (new endpoint in existing router)

```python
# app/routers/auth.py - add after existing endpoints

@router.patch("/me/role-level")
async def update_role_level(
    role_level: str = Query(..., description="Role level: individual_contributor, manager, director, vp, c_suite"),
    user_id: str = Depends(get_current_user)
):
    """Update the user's role level for role-aware coaching."""
    valid_levels = ["individual_contributor", "manager", "director", "vp", "c_suite"]
    if role_level not in valid_levels:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid role_level. Must be one of: {', '.join(valid_levels)}"
        )

    from app.services.profile_store import get_profile_store
    profile_store = get_profile_store()
    profile_store.update_role_level(user_id, role_level)

    # Return updated profile
    profile = profile_store.get_profile(user_id) or {}
    return {"role_level": role_level, **profile}
```

Also update the `/me` endpoint to include role_level:

```python
# app/routers/auth.py - modify existing GET /auth/me endpoint

@router.get("/me")
async def get_current_user(user_id: str = Depends(get_current_user)):
    user = user_service.get_user(user_id)
    user_dict = user.to_dict()

    # Include role_level from profile if available
    from app.services.profile_store import get_profile_store
    profile_store = get_profile_store()
    profile = profile_store.get_profile(user_id)
    if profile and "role_level" in profile:
        user_dict["role_level"] = profile["role_level"]

    return user_dict
```

### 4.3 Update ChatStreamRequest

**File: `app/routers/chat.py`**

```python
# app/routers/chat.py - modify ChatStreamRequest

class ChatStreamRequest(BaseModel):
    sessionId: str
    message: str
    persona: Optional[str] = None
    coachingStyle: Optional[str] = None
    userId: Optional[str] = "anonymous"
    requestId: Optional[str] = None
    userRoleLevel: Optional[str] = None  # NEW: Role level for context
```

### 4.4 Update Coaching Request Construction

**File: `app/routers/chat.py` - modify chat_stream function**

```python
# app/routers/chat.py - update the coaching_req construction

coaching_req = CoachingRequest(
    message=request.message,
    context=f"session_id={request.sessionId}",
    coaching_style=request.coachingStyle,
    user_id=user_id,
    user_role_level=request.userRoleLevel,  # NEW: Pass through role level
    request_id=request_id or None,
)
```

Also update the stream signature function:

```python
def _stream_signature(request: ChatStreamRequest) -> str:
    payload = {
        "session_id": request.sessionId,
        "message": request.message,
        "persona": request.persona,
        "coaching_style": request.coachingStyle,
        "user_id": request.userId or "anonymous",
        "user_role_level": request.userRoleLevel,  # NEW
    }
    raw = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()
```

### 4.5 Update CoachingRequest Model

**File: `app/services/llm.py`**

```python
# app/services/llm.py - add to CoachingRequest

class CoachingRequest(BaseModel):
    message: str
    context: Optional[str] = None
    coaching_style: Optional[str] = None
    user_id: Optional[str] = None
    user_role_level: Optional[str] = None  # NEW
    history: Optional[List[ChatMessage]] = None
    request_id: Optional[str] = None
```

### 4.6 Update Prompt Generation

**File: `app/services/llm_claude.py`**

Add role context function and integrate into system prompt:

```python
# app/services/llm_claude.py - add before get_coaching_response

def _get_role_context(role_level: Optional[str]) -> str:
    """Get role-aware coaching context. This ADDS to existing guardrails, not replaces."""
    if not role_level:
        return ""

    contexts = {
        "individual_contributor": """
User role level: Individual Contributor.
Role-aware focus: Personal impact, skill development, building influence without authority, technical leadership.
Adjust question scope to individual contributions and career progression.
""",
        "manager": """
User role level: Manager.
Role-aware focus: Team performance, direct report development, execution excellence, managing up and across.
Balance coaching between individual growth and team leadership responsibilities.
""",
        "director": """
User role level: Director.
Role-aware focus: Multi-team coordination, managing managers, strategic initiatives, organizational capability.
Questions should explore organizational dynamics and cross-functional alignment.
""",
        "vp": """
User role level: VP/SVP.
Role-aware focus: Business outcomes, P&L responsibility, organizational strategy, executive presence.
Coaching should address strategic decision-making and leadership at scale.
""",
        "c_suite": """
User role level: C-Suite/Founder.
Role-aware focus: Company strategy, board relations, industry positioning, culture and organizational design.
Address high-stakes decision framing and executive-level challenges.
""",
    }
    return contexts.get(role_level, "")

# In get_coaching_response function, add role context to system prompt:
# Around line 820, add to the system prompt construction:

role_context = _get_role_context(request.user_role_level)

system = "\n\n".join(filter(None, [
    GROW_SYSTEM_PROMPT,
    INTERNAL_PERSONA_PROMPTS.get(persona_used),
    f"Coaching style this turn: {style_used}. {style_prompt}",
    role_context,  # NEW: Add role-aware context here
    f"Enhanced with thought leader framework:\n{framework}" if (framework and stage != "diagnose") else None,
    # ... rest of existing prompt construction ...
]))

# IMPORTANT: Role context is added BEFORE stage and inquiry-first instructions
# so that existing guardrails take precedence in conflict cases.
```

### 4.7 Clarify: Role Context vs Existing Guardrails

**Role context is SUBORDINATE to existing coaching guardrails:**

1. **Stage routing** (`_route_stage`): Always determines conversation stage first
2. **Inquiry-first contract** (`enforce_inquiry_first`): When stage="diagnose", ask questions first
3. **Role context**: Provides nuance to questions/recommendations AFTER stage is determined

**Example:**

```
Stage: diagnose (broad user input)
Role context: manager
Result: "As a manager, what's happening with your team that's causing this?" (role-aware question, still diagnosing)

Stage: act (specific, context-rich)
Role context: manager
Result: "Consider setting up 1:1s with each direct report to..." (role-aware recommendation, appropriate stage)
```

---

## 5. Frontend Changes

### 5.1 Update User Model

**File: `CoachingApp/Models/User.swift`**

```swift
// CoachingApp/Models/User.swift

enum RoleLevel: String, Codable, CaseIterable {
    case individualContributor = "individual_contributor"
    case manager = "manager"
    case director = "director"
    case vp = "vp"
    case cSuite = "c_suite"

    var displayName: String {
        switch self {
        case .individualContributor: return "Individual Contributor"
        case .manager: return "Manager"
        case .director: return "Director"
        case .vp: return "VP / SVP"
        case .cSuite: return "C-Suite / Founder"
        }
    }
}

struct User: Codable {
    let id: String
    let email: String
    let fullName: String
    let seatTier: SeatTier
    let preferredPersona: CoachingPersonaType
    let preferredInputMode: InputMode
    let hasCompletedOnboarding: Bool
    let roleLevel: RoleLevel?  // NEW

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case seatTier = "seat_tier"
        case preferredPersona = "preferred_persona"
        case preferredInputMode = "preferred_input_mode"
        case hasCompletedOnboarding = "has_completed_onboarding"
        case roleLevel = "role_level"
    }
}
```

### 5.2 Update AppState

**File: `CoachingApp/App/AppState.swift`**

```swift
// CoachingApp/App/AppState.swift

@Observable
final class AppState {
    // ... existing properties ...
    var userRoleLevel: RoleLevel?  // NEW

    // In applyAuthenticatedUser, add:
    func applyAuthenticatedUser(_ user: User) {
        currentUserId = user.id
        currentUserEmail = user.email
        currentUserName = user.fullName
        serverSeatTier = user.seatTier
        preferredInputMode = user.preferredInputMode
        hasCompletedOnboarding = user.hasCompletedOnboarding
        selectedPersona = subscriptionPlan.supports(persona: user.preferredPersona)
            ? user.preferredPersona
            : .directChallenger
        userRoleLevel = user.roleLevel  // NEW
        isAuthenticated = true

        Task {
            await syncStoreSubscriptionToBackendIfNeeded()
            await refreshEntitlements()
        }
    }
}
```

### 5.3 Persist Role Level During Onboarding

**File: `CoachingApp/Features/Onboarding/OnboardingViewModel.swift`**

```swift
// CoachingApp/Features/Onboarding/OnboardingViewModel.swift

func completeOnboarding() async {
    isCompleting = true
    errorMessage = nil

    do {
        // Apply all onboarding selections to AppState
        appState.selectedCoachingStyle = onboardingData.selectedCoachingStyle

        if !onboardingData.userName.isEmpty {
            appState.currentUserName = onboardingData.userName
        }

        // NEW: Map and persist role level to backend
        if let roleAnswer = onboardingData.userRole.isEmpty ? nil : onboardingData.userRole,
           let roleLevel = mapRoleAnswerToLevel(roleAnswer) {
            try await saveRoleLevel(roleLevel)
            appState.userRoleLevel = roleLevel
        }

        // Mark onboarding as complete
        appState.hasCompletedOnboarding = true

        isCompleting = false
    } catch {
        isCompleting = false
        errorMessage = "Failed to complete onboarding: \(error.localizedDescription)"
    }
}

private func mapRoleAnswerToLevel(_ answer: String) -> RoleLevel? {
    let mapping: [String: RoleLevel] = [
        "Individual Contributor / Senior IC": .individualContributor,
        "Manager / Team Lead": .manager,
        "Director / Senior Manager": .director,
        "VP / SVP": .vp,
        "C-Suite / Founder": .cSuite
    ]
    return mapping[answer]
}

private func saveRoleLevel(_ roleLevel: RoleLevel) async throws {
    // Call the new backend endpoint
    guard let userId = appState.currentUserId else { return }

    var request = URLRequest(url: URL(string: "\(appState.apiEnvironment.baseURL)/auth/me/role-level")!)
    request.httpMethod = "PATCH"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if let token = KeychainService.loadAccessToken() {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
    components.queryItems = [URLQueryItem(name: "role_level", value: roleLevel.rawValue)]
    request.url = components.url

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw URLError(.badServerResponse)
    }
}
```

### 5.4 Update StreamingService

**File: `CoachingApp/Services/Chat/StreamingService.swift`**

```swift
// CoachingApp/Services/Chat/StreamingService.swift

private struct StreamingRequest: Codable {
    let sessionId: String
    let requestId: String
    let message: String
    let persona: String
    let coachingStyle: String?
    let userRoleLevel: String?  // NEW
}

protocol StreamingServiceProtocol: Sendable {
    func streamResponse(
        sessionId: String,
        requestId: String,
        message: String,
        persona: CoachingPersonaType,
        coachingStyle: CoachingStyle?,
        userRoleLevel: RoleLevel?  // NEW
    ) -> AsyncThrowingStream<String, Error>
}

final class StreamingService: NSObject, StreamingServiceProtocol, @unchecked Sendable {
    func streamResponse(
        sessionId: String,
        requestId: String,
        message: String,
        persona: CoachingPersonaType,
        coachingStyle: CoachingStyle? = nil,
        userRoleLevel: RoleLevel? = nil  // NEW
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await performStreamingRequest(
                        sessionId: sessionId,
                        requestId: requestId,
                        message: message,
                        persona: persona,
                        coachingStyle: coachingStyle,
                        userRoleLevel: userRoleLevel,  // NEW
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func performStreamingRequest(
        sessionId: String,
        requestId: String,
        message: String,
        persona: CoachingPersonaType,
        coachingStyle: CoachingStyle?,
        userRoleLevel: RoleLevel?,  // NEW
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        // ... existing URL setup code ...

        let body = StreamingRequest(
            sessionId: sessionId,
            requestId: requestId,
            message: message,
            persona: persona.rawValue,
            coachingStyle: coachingStyle?.apiValue,
            userRoleLevel: userRoleLevel?.rawValue  // NEW
        )
        request.httpBody = try JSONEncoder().encode(body)

        // ... rest of existing streaming code ...
    }
}
```

### 5.5 Update ChatViewModel to Pass Role Level

**File: `CoachingApp/Features/Sessions/Chat/ChatViewModel.swift`**

```swift
// CoachingApp/Features/Sessions/Chat/ChatViewModel.swift

@MainActor
private func streamAssistantResponse(content: String, requestId: String, for session: CoachingSession) async {
    isStreaming = true

    // Create a placeholder assistant message
    let assistantMessage = ChatMessage(
        sessionId: session.id,
        role: .assistant,
        content: "",
        isStreaming: true,
        diagnostics: pendingDiagnostics
    )
    messages.append(assistantMessage)
    pendingDiagnostics = nil

    // NEW: Get role level from AppState
    let roleLevel = appState?.userRoleLevel

    let stream = streamingService.streamResponse(
        sessionId: session.id,
        requestId: requestId,
        message: content,
        persona: session.persona,
        coachingStyle: selectedCoachingStyle,
        userRoleLevel: roleLevel  // NEW
    )
    // ... rest of existing streaming code ...
}
```

### 5.6 Update VoiceViewModel Similarly

**File: `CoachingApp/Features/Sessions/Voice/VoiceViewModel.swift`**

Apply the same changes to pass `userRoleLevel` to streaming calls.

### 5.7 Settings UI for Role Update

**File: `CoachingApp/Features/Profile/AccountSettingsView.swift`**

```swift
// CoachingApp/Features/Profile/AccountSettingsView.swift

struct AccountSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var isUpdatingRole = false
    @State private var updateError: String?

    var body: some View {
        Form {
            // ... existing fields ...

            Section("Role Level") {
                Picker("Current Role", selection: $selectedRoleLevel) {
                    Text("Prefer not to say").tag(nil as RoleLevel?)
                    ForEach(RoleLevel.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level as RoleLevel?)
                    }
                }
                .onChange(of: selectedRoleLevel) { oldValue, newValue in
                    Task {
                        await updateRoleLevel(newValue)
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(updateError != nil)) {
            Button("OK") { updateError = nil }
        } message: {
            Text(updateError ?? "")
        }
    }

    @State private var selectedRoleLevel: RoleLevel?

    init() {
        let appState: AppState = @Environment(\.appState)
        _selectedRoleLevel = State(initialValue: appState.userRoleLevel)
    }

    private func updateRoleLevel(_ roleLevel: RoleLevel?) async {
        guard let roleLevel else { return }
        isUpdatingRole = true
        defer { isUpdatingRole = false }

        do {
            guard let userId = appState.currentUserId else { return }

            var request = URLRequest(url: URL(string: "\(appState.apiEnvironment.baseURL)/auth/me/role-level")!)
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let token = KeychainService.loadAccessToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "role_level", value: roleLevel.rawValue)]
            request.url = components.url

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            appState.userRoleLevel = roleLevel
        } catch {
            updateError = "Failed to update role: \(error.localizedDescription)"
            // Revert selection
            selectedRoleLevel = appState.userRoleLevel
        }
    }
}
```

---

## 6. Migration Strategy

### 6.1 Existing Users

1. **No immediate action required** - role_level is nullable
2. **Optional one-time prompt** (can be enabled later via feature flag):
   ```
   "Help us tailor your coaching: What's your current role level?"
   [Skip] [Individual Contributor] [Manager] [Director] [VP] [C-Suite]
   ```
3. **Infer from behavior** (future): Use ML to suggest role based on conversation topics

### 6.2 Database Migration

The `ProfileStore._ensure_db()` pattern handles migration via the ALTER TABLE clause added in section 4.1. No separate Alembic migration needed.

---

## 7. Testing Plan

### 7.1 Backend Tests

```python
# tests/test_role_aware_coaching.py
import pytest
from app.services.profile_store import ProfileStore, get_profile_store
from app.services.llm import _get_role_context

class TestRoleContextInjection:
    def test_individual_contributor_context(self):
        context = _get_role_context("individual_contributor")
        assert "influence without authority" in context.lower()
        assert "individual contributor" in context.lower()

    def test_manager_context(self):
        context = _get_role_context("manager")
        assert "team performance" in context.lower()
        assert "manager" in context.lower()

    def test_no_context_when_none(self):
        context = _get_role_context(None)
        assert context == ""

    def test_invalid_role_returns_empty(self):
        context = _get_role_context("invalid_role")
        assert context == ""

class TestProfileStoreRoleLevel:
    @pytest.fixture
    def profile_store(self):
        return ProfileStore(database_url=os.getenv("TEST_DATABASE_URL"))

    def test_save_and_retrieve_role_level(self, profile_store):
        user_id = "test_user_role"
        profile_store.save_profile(user_id, {}, role_level="manager")
        profile = profile_store.get_profile(user_id)
        assert profile["role_level"] == "manager"

    def test_update_role_level(self, profile_store):
        user_id = "test_user_update"
        profile_store.save_profile(user_id, {}, role_level="manager")
        profile_store.update_role_level(user_id, "director")
        profile = profile_store.get_profile(user_id)
        assert profile["role_level"] == "director"

class TestChatStreamWithRole:
    async def test_chat_stream_includes_role(self, client, authenticated_user_id):
        response = await client.post(
            "/api/chat/chat-stream",
            json={
                "sessionId": "test-session",
                "message": "I'm struggling with my team",
                "persona": "direct_challenger",
                "coachingStyle": "directive",
                "userRoleLevel": "manager"
            }
        )
        assert response.status_code == 200
```

### 7.2 iOS Tests

```swift
// CoachingAppTests/RoleLevelTests.swift
import XCTest
@testable import CoachingApp

final class RoleLevelTests: XCTestCase {
    var appState: AppState!

    override func setUp() {
        appState = AppState()
    }

    func testRoleMappingFromOnboarding() {
        let mapping: [String: RoleLevel] = [
            "Individual Contributor / Senior IC": .individualContributor,
            "Manager / Team Lead": .manager,
            "Director / Senior Manager": .director,
            "VP / SVP": .vp,
            "C-Suite / Founder": .cSuite
        ]

        XCTAssertEqual(mapping["Individual Contributor / Senior IC"], .individualContributor)
        XCTAssertEqual(mapping["Manager / Team Lead"], .manager)
        XCTAssertEqual(mapping["Director / Senior Manager"], .director)
        XCTAssertEqual(mapping["VP / SVP"], .vp)
        XCTAssertEqual(mapping["C-Suite / Founder"], .cSuite)
    }

    func testStreamingRequestIncludesRoleLevel() throws {
        let encoder = JSONEncoder()
        let request = StreamingRequest(
            sessionId: "test",
            requestId: "req-1",
            message: "hello",
            persona: "direct_challenger",
            coachingStyle: "directive",
            userRoleLevel: "manager"  // NEW field
        )

        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["userRoleLevel"] as? String, "manager")
    }
}
```

### 7.3 E2E Test

```python
# tests/test_e2e_role_aware.py
async def test_coaching_response_differs_by_role(client):
    """Verify that the same question gets different responses based on role level."""
    base_message = "I'm dealing with a difficult colleague"

    # Individual Contributor response should mention "influence without authority"
    response_ic = await client.post(
        "/api/chat/chat-stream",
        json={
            "sessionId": "test-ic",
            "message": base_message,
            "userRoleLevel": "individual_contributor"
        }
    )
    assert "influence" in response.text.lower() or "without authority" in response.text.lower()

    # Manager response should mention "team" or "direct report"
    response_mgr = await client.post(
        "/api/chat/chat-stream",
        json={
            "sessionId": "test-mgr",
            "message": base_message,
            "userRoleLevel": "manager"
        }
    )
    assert "team" in response.text.lower() or "manage" in response.text.lower()
```

---

## 8. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Onboarding role set rate | >80% | % of users with role_level after onboarding |
| Role persistence | 100% | role_level survives app reinstall / device change |
| Settings role update | >5% | % of users who update role in settings per month |
| Perceived relevance | +20% | Survey: "Coaching feels tailored to my role" |
| Backend error rate | <0.1% | Errors related to role_level field |

---

## 9. Rollout Plan

### Phase 1: Backend (Week 1)
1. Update `ProfileStore` with role_level column
2. Add `/auth/me/role-level` PATCH endpoint
3. Update `ChatStreamRequest` and prompt generation
4. Deploy to staging, test with existing backend tests
5. Deploy to production (backward compatible)

### Phase 2: iOS Frontend (Week 2)
1. Add `RoleLevel` enum and update `User` model
2. Update `AppState` to store `userRoleLevel`
3. Update onboarding to persist role to backend
4. Update `StreamingService` and `ChatViewModel`
5. Add role picker to settings
6. Test flight with beta users

### Phase 3: Monitoring (Week 3-4)
1. Monitor backend logs for role_level usage
2. Track onboarding completion rates
3. Gather user feedback on role relevance
4. Iterate on prompt context based on qualitative feedback

---

## 10. Future Enhancements

1. **Dynamic role detection**: Suggest role updates based on conversation topics
2. **Role-specific goal templates**: Different goal suggestions by role level
3. **Role progression tracking**: Celebrate role promotions in-app
4. **Peer matching**: Connect users at similar role levels
5. **Role-specific content**: Curated resources by role level
6. **ML-based role inference**: Predict role from conversation patterns (privacy-preserving)

---

## 11. Open Questions

| Question | Proposed Answer | Status |
|----------|-----------------|--------|
| Should "Prefer not to say" be a valid option? | Yes, for privacy. Role context will be empty. | ✓ Decided |
| How to handle role transitions? | Manual update in settings. Future: detect in conversation. | ✓ Decided |
| Should role affect pricing/entitlements? | No, keep role separate from subscription tier. | ✓ Decided |
| Should we show role context in the UI? | Yes, in profile/settings as "Current Role" | ✓ Decided |
| What if user is in transition between roles? | Allow them to select the role they're aspiring to | Open |

---

## Appendix: File Change Summary

### Backend Files
| File | Change |
|------|--------|
| `app/services/profile_store.py` | Add role_level column, update methods |
| `app/routers/auth.py` | Add PATCH /me/role-level, update GET /me |
| `app/routers/chat.py` | Add userRoleLevel to ChatStreamRequest, pass to CoachingRequest |
| `app/services/llm.py` | Add user_role_level to CoachingRequest |
| `app/services/llm_claude.py` | Add _get_role_context(), integrate into system prompt |

### iOS Files
| File | Change |
|------|--------|
| `Models/User.swift` | Add RoleLevel enum, add roleLevel to User struct |
| `App/AppState.swift` | Add userRoleLevel property |
| `Features/Onboarding/OnboardingViewModel.swift` | Persist role to backend during onboarding |
| `Services/Chat/StreamingService.swift` | Add userRoleLevel to StreamingRequest |
| `Features/Sessions/Chat/ChatViewModel.swift` | Pass role level to streaming |
| `Features/Sessions/Voice/VoiceViewModel.swift` | Pass role level to streaming |
| `Features/Profile/AccountSettingsView.swift` | Add role picker UI |

### Test Files (New)
| File | Purpose |
|------|---------|
| `backend/tests/test_role_aware_coaching.py` | Backend role context tests |
| `CoachingAppTests/RoleLevelTests.swift` | iOS role mapping tests |
| `backend/tests/test_e2e_role_aware.py` | E2E role-aware response tests |
