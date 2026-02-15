import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            SessionsListView()
                .tabItem {
                    Label("Sessions", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(1)

            GoalsListView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.primary)
        .onAppear {
            selectedTab = launchSelectedTab()
        }
    }

    private func launchSelectedTab() -> Int {
        let args = ProcessInfo.processInfo.arguments
        if let arg = args.first(where: { $0.hasPrefix("--open-tab=") }) {
            let value = arg.replacingOccurrences(of: "--open-tab=", with: "")
            switch value {
            case "home": return 0
            case "sessions": return 1
            case "goals": return 2
            case "profile": return 3
            default: return 0
            }
        }
        return 0
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
