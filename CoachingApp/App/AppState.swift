import SwiftUI

@Observable
final class AppState {
    // Bypass auth for testing by default
    var isAuthenticated: Bool = true
    var isLoading: Bool = false
    var hasCompletedOnboarding: Bool = true
    var currentUserId: String? = "test-user-001"
    var currentUserEmail: String? = "test@example.com"
    var currentUserName: String? = "Test User"
    var selectedPersona: CoachingPersonaType = .directChallenger
    var preferredInputMode: InputMode = .text
    var engagementStreak: Int = 0

    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--force-onboarding") {
            hasCompletedOnboarding = false
        }
    }

    func signIn(userId: String, email: String, name: String) {
        currentUserId = userId
        currentUserEmail = email
        currentUserName = name
        isAuthenticated = true
    }

    func signOut() {
        currentUserId = nil
        currentUserEmail = nil
        currentUserName = nil
        isAuthenticated = false
        hasCompletedOnboarding = false
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
