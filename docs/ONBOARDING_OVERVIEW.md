# Onboarding Pages Overview

## ✅ Yes! Onboarding is Fully Implemented

The CoachingApp has a complete 5-step onboarding flow.

---

## Onboarding Flow

### Step 1: Welcome
**File:** `CoachingApp/Features/Onboarding/WelcomeView.swift`

**Content:**
- App logo and branding
- Welcome message
- Feature highlights:
  * AI-Powered Executive Coaching
  * Voice or Text interaction
  * Goal setting and tracking
  * Proven methodology

**Purpose:** Introduce app and set expectations

---

### Step 2: Assessment (About You)
**File:** `CoachingApp/Features/Onboarding/AssessmentView.swift`

**Questions:**
1. **Role** - What best describes your current role?
   - Individual Contributor / Senior IC
   - Manager / Team Lead
   - Director / Senior Manager
   - VP / SVP
   - C-Suite / Founder

2. **Experience** - How many years of leadership experience?
   - Less than 2 years
   - 2-5 years
   - 5-10 years
   - 10-20 years
   - 20+ years

3. **Challenge** - What's your biggest leadership challenge?
   - Navigating organizational politics
   - Building and leading a high-performing team
   - Executive presence and communication
   - Career trajectory and next-level promotion
   - Managing up and stakeholder relationships
   - Work-life balance and avoiding burnout

4. **Coaching Style** - What coaching style do you prefer?
   - Direct and challenging
   - Supportive and strategic
   - A mix of both

5. **Goal Area** - What area would you most like to grow in?
   - Leadership effectiveness
   - Strategic thinking
   - Communication skills
   - Team development
   - Career advancement
   - Confidence and executive presence

**Purpose:** Collect user context for personalized coaching

---

### Step 3: Interaction Style
**File:** `CoachingApp/Features/Onboarding/InputModePreferenceView.swift`

**Options:**
- **Text** - Type messages
- **Voice** - Speak naturally
- **Both** - Switch based on situation

**Purpose:** Set preferred input mode

---

### Step 4: Coach Persona Selection
**File:** `CoachingApp/Features/Onboarding/PersonaSelectionView.swift`

**Personas:**
- **Direct Challenger** - Tells you what you need to hear
- **Supportive Guide** - Helps you think it through
- **Strategic Partner** - Focuses on long-term planning

**Purpose:** Match user with coaching persona

---

### Step 5: First Goal Setup
**File:** `CoachingApp/Features/Onboarding/FirstGoalSetupView.swift`

**Fields:**
- Goal title
- Goal description

**Purpose:** Get user started with their first goal

---

## Architecture

### Models
**File:** `CoachingApp/Models/OnboardingData.swift`

```swift
struct OnboardingData {
    var assessmentAnswers: [AssessmentAnswer]
    var preferredInputMode: InputMode
    var selectedPersona: CoachingPersonaType
    var firstGoalTitle: String
    var firstGoalDescription: String
    var userName: String
    var userRole: String
}

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case assessment = 1
    case inputMode = 2
    case personaSelection = 3
    case firstGoal = 4
}
```

### ViewModel
**File:** `CoachingApp/Features/Onboarding/OnboardingViewModel.swift`

**Responsibilities:**
- Manages onboarding state
- Handles step navigation
- Saves onboarding data
- Communicates with AppState

### Main View
**File:** `CoachingApp/Features/Onboarding/OnboardingView.swift`

**Features:**
- Progress bar with step indicator
- Skip button
- Navigation buttons (Back/Continue)
- Smooth animations between steps
- TabView for swipe navigation

---

## UI/UX Features

✅ **Progress Tracking**
- Visual progress bar
- Step counter ("Step X of 5")
- Step title display

✅ **Navigation**
- Back/Continue buttons
- Skip option
- Swipe between steps

✅ **Animations**
- Smooth transitions between steps
- Progress bar animations
- Button interactions

✅ **Design System**
- Consistent with app theme
- Uses AppTheme, AppFonts, AppSpacing
- Dark mode support

---

## Onboarding Data Flow

```
User completes onboarding
        ↓
OnboardingViewModel collects data
        ↓
AppState saves to UserDefaults
        ↓
On next launch:
- If onboarding complete → Show HomeView
- If not complete → Show OnboardingView
```

---

## Key Files

| File | Purpose |
|------|---------|
| `OnboardingView.swift` | Main container view |
| `OnboardingViewModel.swift` | Business logic |
| `OnboardingData.swift` | Data models |
| `WelcomeView.swift` | Welcome screen |
| `AssessmentView.swift` | Assessment questions |
| `InputModePreferenceView.swift` | Input mode selection |
| `PersonaSelectionView.swift` | Coach persona picker |
| `FirstGoalSetupView.swift` | First goal form |

---

## Assessment Questions Detail

All questions are defined in `OnboardingData.swift`:

```swift
enum OnboardingAssessment {
    static let questions: [AssessmentQuestion] = [
        AssessmentQuestion(
            id: "role",
            question: "What best describes your current role?",
            subtitle: "This helps us tailor coaching to your level",
            options: [...]
        ),
        // ... 4 more questions
    ]
}
```

**Question Types:**
- Multiple choice (4 questions)
- Free text (0 questions currently, but supported)

---

## Integration Points

### AppState Integration
```swift
// In AppState.swift
@Published var hasCompletedOnboarding: Bool = false

func completeOnboarding(data: OnboardingData) {
    self.hasCompletedOnboarding = true
    self.userProfile = UserProfile(from: data)
    // Save to UserDefaults
}
```

### Backend Integration
Onboarding data can be sent to backend:
```swift
// POST /api/user/onboarding
{
    "role": "Manager / Team Lead",
    "experience_years": 5,
    "biggest_challenge": "Building and leading a high-performing team",
    "preferred_style": "supportive",
    "goal_area": "Leadership effectiveness",
    "input_mode": "text",
    "first_goal": {
        "title": "...",
        "description": "..."
    }
}
```

---

## Testing Onboarding

### Manual Testing
1. Delete app and reinstall
2. Launch app
3. Should see OnboardingView
4. Complete all 5 steps
5. Should see HomeView on next launch

### Skip Testing
1. Launch app
2. Tap "Skip" button
3. Should go directly to HomeView
4. Onboarding marked as complete

---

## Future Enhancements

Potential improvements:
- [ ] Add more assessment questions
- [ ] Add free-text questions
- [ ] Personalized onboarding based on role
- [ ] Video tutorials in welcome
- [ ] Animated coach persona previews
- [ ] Goal templates based on challenge selection
- [ ] Skip individual questions
- [ ] Save progress between sessions

---

## Summary

✅ **Fully Implemented:** 5-step onboarding flow
✅ **Data Collection:** Role, experience, challenges, preferences, goals
✅ **UI/UX:** Progress tracking, skip option, smooth animations
✅ **Integration:** AppState, UserDefaults, ready for backend
✅ **Quality:** Consistent design system, dark mode support

**Total Files:** 7 Swift files
**Total Steps:** 5 onboarding steps
**Assessment Questions:** 5 questions

The onboarding system is production-ready and comprehensive! 🎉
