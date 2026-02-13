import Foundation

@Observable
final class ProfileViewModel {
    var userName: String = ""
    var userEmail: String = ""
    var selectedPersona: CoachingPersonaType = .directChallenger
    var voiceRate: Double = 0.5
    var voiceEnabled: Bool = false
    var isLoading: Bool = false

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        loadFromAppState()
    }

    // MARK: - Load State

    private func loadFromAppState() {
        userName = appState.currentUserName ?? ""
        userEmail = appState.currentUserEmail ?? ""
        selectedPersona = appState.selectedPersona
    }

    // MARK: - Actions

    func updateProfile() async {
        isLoading = true
        defer { isLoading = false }

        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(500))

        appState.currentUserName = userName
        appState.selectedPersona = selectedPersona
    }

    func updatePersona(_ persona: CoachingPersonaType) {
        selectedPersona = persona
        appState.selectedPersona = persona
    }

    func signOut() {
        appState.signOut()
    }

    func exportData() async {
        isLoading = true
        defer { isLoading = false }

        // Simulate export delay
        try? await Task.sleep(for: .seconds(2))

        // In a real app, this would trigger a data export
    }
}
