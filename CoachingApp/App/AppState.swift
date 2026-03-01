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
            return "https://coachingapp-api.railway.app/api/v1"
        case .staging:
            return "https://staging-coachingapp.railway.app/api/v1"
        }
    }

    /// Full URL for the SSE chat-stream endpoint (not under /api/v1)
    var chatStreamURL: String {
        switch self {
        case .localhost:
            return "http://localhost:8000/api/chat/chat-stream"
        case .production:
            return "https://coachingapp-api.railway.app/api/chat/chat-stream"
        case .staging:
            return "https://staging-coachingapp.railway.app/api/chat/chat-stream"
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
    var isAuthenticated: Bool = false
    var isLoading: Bool = true   // start loading so splash doesn't flash SignInView
    var hasCompletedOnboarding: Bool = true
    var currentUserId: String? = nil
    var currentUserEmail: String? = nil
    var currentUserName: String? = nil
    var selectedPersona: CoachingPersonaType = .directChallenger
    var selectedCoachingStyle: CoachingStyle = .auto
    var showDebugDiagnostics: Bool = false
    
    // Use mock services (no real API calls). Defaults to false — real Railway backend.
    var useMockServices: Bool = false
    
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
