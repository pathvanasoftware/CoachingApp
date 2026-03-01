import SwiftUI

// MARK: - API Environment

enum APIEnvironment: String, CaseIterable {
    case localhost = "Local"
    case production = "Production"
    case staging = "Staging"

    var baseURL: String {
        switch self {
        case .localhost:
            return "http://localhost:8000/api/v1"
        case .production:
            // TODO: Replace with actual production URL after deployment
            return "https://coachingapp-api.railway.app/api/v1"
        case .staging:
            // TODO: Replace with staging URL if needed
            return "https://staging-coachingapp.railway.app/api/v1"
        }
    }

    var description: String {
        switch self {
        case .localhost:
            return "Local Development (localhost:8000)"
        case .production:
            return "Production"
        case .staging:
            return "Staging"
        }
    }
}

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
    var selectedCoachingStyle: CoachingStyle = .auto
    var showDebugDiagnostics: Bool = false
    
    // Force use mock services (no real API calls)
    var useMockServices: Bool = true
    
    var apiEnvironment: APIEnvironment = {
        if let saved = UserDefaults.standard.string(forKey: "com.coachingapp.apiEnvironment"),
           let env = APIEnvironment(rawValue: saved) {
            return env
        }
        #if DEBUG
        return .localhost
        #else
        return .production
        #endif
    }()
    var preferredInputMode: InputMode = .text
    var engagementStreak: Int = 0

    init() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--force-onboarding") {
            hasCompletedOnboarding = false
        }
        if args.contains("--debug-diagnostics") {
            showDebugDiagnostics = true
        }
        if args.contains("--use-real-api") {
            useMockServices = false
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

    func switchAPIEnvironment(_ environment: APIEnvironment) {
        apiEnvironment = environment
        UserDefaults.standard.set(environment.rawValue, forKey: "com.coachingapp.apiEnvironment")
    }
}
