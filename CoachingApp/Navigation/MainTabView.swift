import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            SessionsListView()
                .tabItem {
                    Label("Sessions", systemImage: "bubble.left.and.bubble.right.fill")
                }

            GoalsListView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(AppTheme.primary)
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
