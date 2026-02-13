import SwiftUI

@Observable
final class AppState {
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var hasCompletedOnboarding: Bool = false
    var currentUserId: String?
    var currentUserEmail: String?
    var currentUserName: String?
    var selectedPersona: CoachingPersonaType = .directChallenger
    var preferredInputMode: InputMode = .text
    var engagementStreak: Int = 0

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
