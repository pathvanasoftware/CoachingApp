import Foundation

@Observable
final class SessionsViewModel {

    // MARK: - Published State

    var sessions: [CoachingSession] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let chatService: ChatServiceProtocol

    // MARK: - Init

    init(chatService: ChatServiceProtocol = MockChatService.shared) {
        self.chatService = chatService
    }

    // MARK: - Grouped Sessions

    /// Sessions grouped by week, with the most recent week first.
    var groupedSessions: [(key: String, sessions: [CoachingSession])] {
        let calendar = Calendar.current

        let grouped = Dictionary(grouping: sessions) { session -> String in
            let startOfWeek = session.startedAt.startOfWeek
            if calendar.isDate(startOfWeek, equalTo: Date().startOfWeek, toGranularity: .weekOfYear) {
                return "This Week"
            } else {
                let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: Date().startOfWeek) ?? Date()
                if calendar.isDate(startOfWeek, equalTo: previousWeekStart, toGranularity: .weekOfYear) {
                    return "Last Week"
                } else {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    let weekEnd = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? startOfWeek
                    return "Week of \(formatter.string(from: startOfWeek)) - \(formatter.string(from: weekEnd))"
                }
            }
        }

        // Sort groups: "This Week" first, then "Last Week", then by date descending
        return grouped.map { (key: $0.key, sessions: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { first, second in
                if first.key == "This Week" { return true }
                if second.key == "This Week" { return false }
                if first.key == "Last Week" { return true }
                if second.key == "Last Week" { return false }
                return first.key > second.key
            }
    }

    /// Active sessions (not yet ended).
    var activeSessions: [CoachingSession] {
        sessions.filter { $0.isActive }
    }

    /// Completed sessions.
    var completedSessions: [CoachingSession] {
        sessions.filter { !$0.isActive }
    }

    // MARK: - Actions

    @MainActor
    func loadSessions(userId: String = "mock-user-id") async {
        isLoading = true
        errorMessage = nil

        do {
            sessions = try await chatService.getSessionHistory(userId: userId)
        } catch {
            errorMessage = "Failed to load sessions: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    func deleteSession(at offsets: IndexSet, from sectionSessions: [CoachingSession]) {
        for offset in offsets {
            let session = sectionSessions[offset]
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions.remove(at: index)
            }
        }
    }

    @MainActor
    func deleteSession(id: String) {
        sessions.removeAll { $0.id == id }
    }
}
