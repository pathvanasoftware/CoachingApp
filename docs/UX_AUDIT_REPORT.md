# UX Audit Report - CoachingApp

**Date:** 2026-02-22
**Auditor:** Claw (OpenClaw PM Agent)
**App Version:** main (bf8255b)

---

## 📊 Executive Summary

**Overall UX Score: 7/10**

**Strengths:**
- ✅ Complete onboarding flow with skip option
- ✅ Proper loading states
- ✅ Error handling in Home view
- ✅ Consistent design system (AppTheme)
- ✅ Accessibility labels on quick replies

**Critical Issues:**
- 🔴 No network error recovery in chat
- 🔴 No haptic feedback on interactions
- 🔴 Missing first-time user guidance
- 🔴 Unclear session save confirmation

---

## 🎯 Priority Fixes (P0 - Must Fix Before Launch)

### 1. **Network Failure in Chat** 🔴
**Location:** `ChatScreen.swift`, `ChatViewModel.swift`

**Problem:**
- User sends message → network fails → message disappears
- No indication of failure
- No retry mechanism

**Impact:** Users lose work, frustration, trust issues

**Fix:**
```swift
// Add retry button for failed messages
struct ChatMessage {
    let id: String
    let content: String
    let role: Role
    var status: MessageStatus = .sent
    // .sending, .sent, .failed
}

// Show failed state
if message.status == .failed {
    Button("Retry") {
        retryMessage(message.id)
    }
}
```

**Effort:** 1-2 hours

---

### 2. **No Haptic Feedback** 🔴
**Location:** All interactive elements

**Problem:**
- Buttons feel "dead" (no vibration feedback)
- iOS users expect haptic feedback

**Impact:** Feels unpolished, less engaging

**Fix:**
```swift
import UIKit

// Add to button actions
let generator = UIImpactFeedbackGenerator(style: .light)
generator.impactOccurred()
```

**Apply to:**
- Quick reply taps
- Send message
- Style selection
- Goal completion toggle

**Effort:** 30 minutes

---

### 3. **Missing Session Save Confirmation** 🔴
**Location:** `ChatViewModel.swift`, `ChatHistoryStorage.swift`

**Problem:**
- Chat saves automatically (good!)
- But user doesn't KNOW it's saving
- Closing app might feel risky

**Fix:**
```swift
// Add subtle indicator
@State private var lastSavedTime: Date?
@State private var showSaveIndicator = false

// In save logic
Task {
    await chatStorage.save(messages: messages)
    await MainActor.run {
        lastSavedTime = Date()
        showSaveIndicator = true
        // Auto-hide after 2s
        try? await Task.sleep(for: .seconds(2))
        showSaveIndicator = false
    }
}

// In header
if showSaveIndicator {
    Text("Saved")
        .font(.caption2)
        .foregroundStyle(.green)
        .transition(.opacity)
}
```

**Effort:** 1 hour

---

## 🟡 Important Improvements (P1 - Polish)

### 4. **Onboarding Skip Recovery**
**Location:** `OnboardingView.swift`

**Problem:**
- User can skip onboarding
- But no way to restart it later
- If they regret skipping, they're stuck

**Fix:**
```swift
// Add in ProfileView
Section {
    Button("Restart Onboarding") {
        appState.hasCompletedOnboarding = false
    }
}
```

**Effort:** 15 minutes

---

### 5. **Empty State Improvements**
**Location:** `GoalsListView.swift`, `SessionsListView.swift`

**Problem:**
- Empty states exist but are plain
- No illustrations or personality
- Could be more engaging

**Fix:**
```swift
// Use illustrations + humor
EmptyStateView(
    icon: "target",
    title: "No goals yet!",
    message: "Ready to set your first goal? Let's aim high! 🎯",
    buttonTitle: "Create Goal",
    action: { showingAddGoal = true }
)
```

**Effort:** 30 minutes

---

### 6. **Chat Input Placeholder**
**Location:** `ChatScreen.swift` input area

**Problem:**
- Generic placeholder: "Type your message..."
- Doesn't guide user on what to ask

**Fix:**
```swift
// Dynamic placeholders based on context
var inputPlaceholder: String {
    if messages.isEmpty {
        return "What's on your mind today?"
    } else if recentEmotion == "stressed" {
        return "Share what's stressing you..."
    } else {
        return "Continue the conversation..."
    }
}

TextField(inputPlaceholder, text: $viewModel.currentInput)
```

**Effort:** 20 minutes

---

### 7. **Typing Indicator Timing**
**Location:** `ChatScreen.swift`, `TypingIndicatorView.swift`

**Problem:**
- Typing indicator appears immediately
- Feels robotic if AI responds instantly
- Real humans have slight delay

**Fix:**
```swift
// Add natural delay
func sendMessage() async {
    // Show typing after 200ms (feels more natural)
    try? await Task.sleep(for: .milliseconds(200))
    isStreaming = true

    // Then call API
    await actuallySendMessage()
}
```

**Effort:** 15 minutes

---

### 8. **Message Send Button State**
**Location:** `ChatScreen.swift` input area

**Problem:**
- Send button always enabled
- Tapping with empty input does nothing
- No visual feedback

**Fix:**
```swift
Button(action: sendMessage) {
    Image(systemName: "arrow.up.circle.fill")
        .font(.title2)
        .foregroundStyle(
            currentInput.trimmingCharacters(in: .whitespaces).isEmpty
                ? .gray
                : .blue
        )
}
.disabled(currentInput.trimmingCharacters(in: .whitespaces).isEmpty)
```

**Effort:** 10 minutes

---

## 🔵 Nice to Have (P2 - Future)

### 9. **Pull to Refresh in Chat**
**Location:** `ChatScreen.swift`

**Problem:**
- No way to reload messages if sync fails
- Pull-to-refresh expected pattern

**Fix:**
```swift
ScrollView {
    // ...
}
.refreshable {
    await reloadMessages()
}
```

**Effort:** 30 minutes

---

### 10. **Message Timestamps Toggle**
**Location:** `MessageBubbleView.swift`

**Problem:**
- Timestamps always shown (clutter)
- Some users prefer cleaner view

**Fix:**
```swift
// Tap message to show timestamp
@State private var showTimestamps: Set<String> = []

TapGesture on message {
    if showTimestamps.contains(message.id) {
        showTimestamps.remove(message.id)
    } else {
        showTimestamps.insert(message.id)
    }
}
```

**Effort:** 45 minutes

---

### 11. **Coaching Style Preview**
**Location:** `ChatScreen.swift` style picker

**Problem:**
- 4 styles, but users don't know difference
- No preview of what each style offers

**Fix:**
```swift
Menu {
    ForEach(CoachingStyle.allCases) { style in
        Button {
            selectedStyle = style
        } label: {
            VStack(alignment: .leading) {
                Text(style.displayName)
                Text(style.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

**Effort:** 30 minutes

---

## 🎨 Visual Polish (P2)

### 12. **Gradient Backgrounds**
- Chat bubbles could use subtle gradients
- Headers could have gradient backgrounds

### 13. **Smooth Transitions**
- Add `.transition(.asymmetric(...))` for message animations
- Slide in from bottom for new messages

### 14. **Sound Effects** (Optional)
- Subtle "pop" when quick reply sent
- Success sound when goal completed

---

## ♿ Accessibility Audit

### Current State: 8/10

**✅ What's Good:**
- Accessibility labels on quick replies
- Proper button traits
- Navigation support

**❌ What's Missing:**
- Dynamic Type support (text scaling)
- VoiceOver announcements for new messages
- Reduce Motion support for animations
- High contrast mode support

**Fix Priority:** P1 (before launch)

---

## 📱 Platform-Specific Issues

### iOS-Specific:
1. **Swipe Back Gesture** - Check if all screens support edge swipe
2. **Keyboard Handling** - Verify keyboard doesn't hide input field
3. **Safe Areas** - Check notch/Dynamic Island handling

### iPad:
1. **Landscape Support** - Verify all views work in landscape
2. **Split View** - Test with other apps open
3. **Keyboard Shortcuts** - Add Cmd+Enter to send

---

## 🧪 Testing Recommendations

### User Testing Scenarios:
1. **First-time user** - Fresh install, no guidance
2. **Network failure** - Airplane mode during chat
3. **Long session** - 50+ messages, test performance
4. **Goal completion** - Celebrate achievements
5. **Crisis flow** - Test crisis detection UX

### A/B Test Ideas:
1. Quick reply button styles (filled vs outlined)
2. Typing indicator timing (instant vs delayed)
3. Onboarding: with vs without persona selection

---

## 📈 Metrics to Track

**Post-Launch:**
- Message send success rate
- Onboarding completion rate
- Time to first message
- Goal completion rate
- Session export usage
- Human coach request rate

---

## 🚀 Implementation Roadmap

### Week 1 (P0 Fixes):
- [ ] Network failure recovery (2h)
- [ ] Haptic feedback (30m)
- [ ] Save confirmation (1h)
- [ ] Accessibility improvements (2h)

**Total: ~6 hours**

### Week 2 (P1 Polish):
- [ ] Onboarding skip recovery (15m)
- [ ] Empty states (30m)
- [ ] Input placeholder (20m)
- [ ] Typing indicator timing (15m)
- [ ] Send button states (10m)

**Total: ~1.5 hours**

### Week 3 (P2 Nice-to-Have):
- [ ] Pull to refresh (30m)
- [ ] Timestamp toggle (45m)
- [ ] Style previews (30m)
- [ ] Visual polish (2h)

**Total: ~4 hours**

---

## 🎯 Success Criteria

**Must Have Before Launch:**
- ✅ Network error recovery
- ✅ Haptic feedback
- ✅ Accessibility score > 9/10
- ✅ All P0 issues resolved

**Nice to Have:**
- [ ] All P1 issues resolved
- [ ] User testing completed
- [ ] 90%+ satisfaction in beta

---

## 📝 Next Steps

1. **Review this report** with user (blurjp)
2. **Prioritize** which fixes to implement
3. **Create issues** for each fix
4. **Sprint planning** (I can implement immediately)
5. **User testing** after P0 fixes

---

**Generated by:** Claw 🦞
**Confidence:** High (based on code analysis)
**Recommendation:** Fix P0 issues before any user-facing launch
