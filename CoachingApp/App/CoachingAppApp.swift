import SwiftUI
import SwiftData

@main
struct CoachingAppApp: App {
    @State private var appState = AppState()
    @State private var authService = AuthService()
    @State private var services = ServiceContainer()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoading {
                    LoadingView(message: "Loading...")
                } else if !appState.isAuthenticated {
                    SignInView()
                } else if !appState.hasCompletedOnboarding {
                    OnboardingView(appState: appState)
                } else {
                    MainTabView()
                }
            }
            .environment(appState)
            .environment(authService)
            .environment(services)
            .task {
                services.configure(useMockServices: appState.useMockServices)
                await restoreSession()
            }
        }
    }

    /// Attempt to restore a session from Keychain on launch.
    /// Falls back gracefully to sign-in screen if no valid session exists.
    private func restoreSession() async {
        appState.isLoading = true
        defer { appState.isLoading = false }

        await authService.restoreSession()

        if authService.isAuthenticated, let user = authService.currentUser {
            appState.signIn(
                userId: user.id,
                email: user.email,
                name: user.fullName ?? ""
            )
        }
    }
}
