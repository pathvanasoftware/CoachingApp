import SwiftUI
import SwiftData

@main
struct CoachingAppApp: App {
    @State private var appState = AppState()

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
        }
    }
}
