import SwiftUI

@Observable
final class Router {
    var homePath = NavigationPath()
    var sessionsPath = NavigationPath()
    var goalsPath = NavigationPath()
    var profilePath = NavigationPath()

    enum Route: Hashable {
        case chat(sessionId: String?)
        case sessionDetail(id: String)
        case goalDetail(id: String)
        case voiceMode
        case personaSettings
        case voiceSettings
        case accountSettings
    }

    func navigate(to route: Route, in tab: Tab = .home) {
        switch tab {
        case .home:
            homePath.append(route)
        case .sessions:
            sessionsPath.append(route)
        case .goals:
            goalsPath.append(route)
        case .profile:
            profilePath.append(route)
        }
    }

    func goBack(in tab: Tab = .home) {
        switch tab {
        case .home:
            guard !homePath.isEmpty else { return }
            homePath.removeLast()
        case .sessions:
            guard !sessionsPath.isEmpty else { return }
            sessionsPath.removeLast()
        case .goals:
            guard !goalsPath.isEmpty else { return }
            goalsPath.removeLast()
        case .profile:
            guard !profilePath.isEmpty else { return }
            profilePath.removeLast()
        }
    }

    func resetToRoot(tab: Tab) {
        switch tab {
        case .home:
            homePath = NavigationPath()
        case .sessions:
            sessionsPath = NavigationPath()
        case .goals:
            goalsPath = NavigationPath()
        case .profile:
            profilePath = NavigationPath()
        }
    }

    enum Tab: String, CaseIterable {
        case home
        case sessions
        case goals
        case profile
    }
}
