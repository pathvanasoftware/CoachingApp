import Foundation

@Observable
final class HomeViewModel {
    var actionItems: [ActionItem] = []
    var recentSessions: [CoachingSession] = []
    var isLoading: Bool = false

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }

    var todayActionItems: [ActionItem] {
        actionItems.filter { $0.isDueToday && !$0.isCompleted }
    }

    var overdueActionItems: [ActionItem] {
        actionItems.filter { $0.isOverdue }
    }

    var completedTodayCount: Int {
        actionItems.filter { $0.isDueToday && $0.isCompleted }.count
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // Never block UI for long - fail open with local sample data.
        let work = Task {
            try? await Task.sleep(for: .milliseconds(400))
            return (Self.sampleActionItems, Self.sampleSessions)
        }

        let fallback = Task {
            try? await Task.sleep(for: .seconds(2))
            return (Self.sampleActionItems, Self.sampleSessions)
        }

        let result = await withTaskGroup(of: ([ActionItem], [CoachingSession]).self) { group in
            group.addTask { await work.value }
            group.addTask { await fallback.value }
            let first = await group.next() ?? (Self.sampleActionItems, Self.sampleSessions)
            group.cancelAll()
            return first
        }

        actionItems = result.0
        recentSessions = result.1
    }

    func toggleActionItem(_ item: ActionItem) {
        guard let index = actionItems.firstIndex(where: { $0.id == item.id }) else { return }
        actionItems[index].isCompleted.toggle()
        actionItems[index].completedAt = actionItems[index].isCompleted ? Date() : nil
    }

    func startNewSession() {
        // Placeholder -- will be connected to session navigation
    }

    // MARK: - Sample Data

    private static let sampleActionItems: [ActionItem] = [
        ActionItem(
            id: "ai-1",
            sessionId: "session-1",
            userId: "user-1",
            title: "Schedule 1:1 with VP of Engineering",
            description: "Discuss the Q2 roadmap alignment",
            dueDate: Date()
        ),
        ActionItem(
            id: "ai-2",
            sessionId: "session-1",
            userId: "user-1",
            title: "Draft talking points for board presentation",
            description: "Focus on growth metrics and strategic initiatives",
            dueDate: Date()
        ),
        ActionItem(
            id: "ai-3",
            sessionId: "session-2",
            userId: "user-1",
            title: "Practice active listening in next team meeting",
            description: "Take notes on team concerns without immediately responding",
            dueDate: Date()
        ),
        ActionItem(
            id: "ai-4",
            sessionId: "session-2",
            userId: "user-1",
            title: "Review leadership book chapter 5",
            description: "Focus on delegation frameworks",
            isCompleted: false,
            dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
        )
    ]

    private static let sampleSessions: [CoachingSession] = [
        CoachingSession(
            id: "session-1",
            userId: "user-1",
            persona: .directChallenger,
            sessionType: .deepDive,
            startedAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date(),
            endedAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
            summary: "Explored strategies for the upcoming board presentation and identified key areas to strengthen your narrative.",
            durationSeconds: 1800,
            messageCount: 24
        ),
        CoachingSession(
            id: "session-2",
            userId: "user-1",
            persona: .supportiveStrategist,
            sessionType: .checkIn,
            startedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            endedAt: Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.date(byAdding: .minute, value: 25, to: Date()) ?? Date()),
            summary: "Discussed challenges with team communication and created an action plan for improving 1:1 meetings.",
            durationSeconds: 1500,
            messageCount: 18
        ),
        CoachingSession(
            id: "session-3",
            userId: "user-1",
            persona: .directChallenger,
            sessionType: .goalReview,
            startedAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            endedAt: Calendar.current.date(byAdding: .day, value: -3, to: Calendar.current.date(byAdding: .minute, value: 20, to: Date()) ?? Date()),
            summary: "Reviewed progress on strategic thinking goal. Identified need for more practice with frameworks.",
            durationSeconds: 1200,
            messageCount: 15
        )
    ]
}
