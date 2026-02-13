import Foundation

// MARK: - Mock Goal Service

final class MockGoalService: GoalServiceProtocol, @unchecked Sendable {

    // MARK: - In-Memory Storage

    private var goals: [String: Goal]

    // MARK: - Configuration

    /// Simulated network delay in nanoseconds (default: 0.5 seconds).
    var simulatedDelay: UInt64 = 500_000_000

    // MARK: - Init

    init() {
        // Pre-populate with sample goals
        let sampleGoals = Self.createSampleGoals()
        var storage: [String: Goal] = [:]
        for goal in sampleGoals {
            storage[goal.id] = goal
        }
        self.goals = storage
    }

    // MARK: - GoalServiceProtocol

    func fetchGoals(userId: String) async throws -> [Goal] {
        try await Task.sleep(nanoseconds: simulatedDelay)

        return goals.values
            .filter { $0.userId == userId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createGoal(goal: Goal) async throws -> Goal {
        try await Task.sleep(nanoseconds: simulatedDelay)

        var newGoal = goal
        if newGoal.id.isEmpty {
            newGoal = Goal(
                userId: goal.userId,
                title: goal.title,
                description: goal.description,
                status: goal.status,
                progress: goal.progress,
                targetDate: goal.targetDate,
                milestones: goal.milestones,
                relatedSessionIds: goal.relatedSessionIds
            )
        }

        goals[newGoal.id] = newGoal
        return newGoal
    }

    func updateGoal(goal: Goal) async throws -> Goal {
        try await Task.sleep(nanoseconds: simulatedDelay)

        guard goals[goal.id] != nil else {
            throw GoalServiceError.goalNotFound
        }

        var updated = goal
        updated.updatedAt = Date()
        goals[goal.id] = updated
        return updated
    }

    func deleteGoal(goalId: String) async throws {
        try await Task.sleep(nanoseconds: simulatedDelay)

        guard goals.removeValue(forKey: goalId) != nil else {
            throw GoalServiceError.goalNotFound
        }
    }

    func addMilestone(goalId: String, milestone: Milestone) async throws -> Goal {
        try await Task.sleep(nanoseconds: simulatedDelay)

        guard var goal = goals[goalId] else {
            throw GoalServiceError.goalNotFound
        }

        goal.milestones.append(milestone)
        goal.updatedAt = Date()

        // Recalculate progress
        let completedCount = goal.milestones.filter { $0.isCompleted }.count
        goal.progress = goal.milestones.isEmpty ? 0 : Double(completedCount) / Double(goal.milestones.count)

        goals[goalId] = goal
        return goal
    }

    func toggleMilestone(goalId: String, milestoneId: String) async throws -> Goal {
        try await Task.sleep(nanoseconds: simulatedDelay)

        guard var goal = goals[goalId] else {
            throw GoalServiceError.goalNotFound
        }

        guard let milestoneIndex = goal.milestones.firstIndex(where: { $0.id == milestoneId }) else {
            throw GoalServiceError.milestoneNotFound
        }

        goal.milestones[milestoneIndex].isCompleted.toggle()
        goal.milestones[milestoneIndex].completedAt = goal.milestones[milestoneIndex].isCompleted ? Date() : nil

        // Recalculate progress
        let completedCount = goal.milestones.filter { $0.isCompleted }.count
        goal.progress = goal.milestones.isEmpty ? 0 : Double(completedCount) / Double(goal.milestones.count)

        goal.updatedAt = Date()
        goals[goalId] = goal
        return goal
    }

    // MARK: - Sample Data

    private static func createSampleGoals() -> [Goal] {
        let userId = "mock-user-001"
        let now = Date()
        let calendar = Calendar.current

        let goal1 = Goal(
            id: "goal-001",
            userId: userId,
            title: "Improve Executive Presence",
            description: "Develop a stronger executive presence in leadership meetings, focusing on concise communication, strategic framing, and confident delivery.",
            status: .active,
            progress: 0.4,
            targetDate: calendar.date(byAdding: .month, value: 2, to: now),
            milestones: [
                Milestone(
                    id: "ms-001",
                    title: "Record and review one meeting performance",
                    isCompleted: true,
                    completedAt: calendar.date(byAdding: .day, value: -10, to: now)
                ),
                Milestone(
                    id: "ms-002",
                    title: "Practice 2-minute strategic framing exercise daily for one week",
                    isCompleted: true,
                    completedAt: calendar.date(byAdding: .day, value: -5, to: now)
                ),
                Milestone(
                    id: "ms-003",
                    title: "Lead next all-hands Q&A section without notes",
                    isCompleted: false
                ),
                Milestone(
                    id: "ms-004",
                    title: "Get feedback from 3 peers on communication clarity",
                    isCompleted: false
                ),
                Milestone(
                    id: "ms-005",
                    title: "Present quarterly strategy to leadership team",
                    isCompleted: false
                )
            ],
            relatedSessionIds: ["session-001", "session-002"],
            createdAt: calendar.date(byAdding: .weekOfYear, value: -3, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now
        )

        let goal2 = Goal(
            id: "goal-002",
            userId: userId,
            title: "Build High-Performing Team Culture",
            description: "Create a team environment where psychological safety, accountability, and high performance coexist. Focus on 1:1 coaching and team rituals.",
            status: .active,
            progress: 0.33,
            targetDate: calendar.date(byAdding: .month, value: 3, to: now),
            milestones: [
                Milestone(
                    id: "ms-006",
                    title: "Implement weekly 1:1 framework with all direct reports",
                    isCompleted: true,
                    completedAt: calendar.date(byAdding: .day, value: -7, to: now)
                ),
                Milestone(
                    id: "ms-007",
                    title: "Run team retrospective focused on psychological safety",
                    isCompleted: false
                ),
                Milestone(
                    id: "ms-008",
                    title: "Establish team OKRs with individual accountability",
                    isCompleted: false
                )
            ],
            relatedSessionIds: ["session-003"],
            createdAt: calendar.date(byAdding: .weekOfYear, value: -2, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now
        )

        let goal3 = Goal(
            id: "goal-003",
            userId: userId,
            title: "Navigate Promotion to VP",
            description: "Strategically position for promotion to VP level by building visibility, demonstrating cross-functional impact, and cultivating executive sponsors.",
            status: .active,
            progress: 0.2,
            targetDate: calendar.date(byAdding: .month, value: 6, to: now),
            milestones: [
                Milestone(
                    id: "ms-009",
                    title: "Identify and meet with 2 potential executive sponsors",
                    isCompleted: true,
                    completedAt: calendar.date(byAdding: .day, value: -14, to: now)
                ),
                Milestone(
                    id: "ms-010",
                    title: "Volunteer to lead a cross-functional initiative",
                    isCompleted: false
                ),
                Milestone(
                    id: "ms-011",
                    title: "Document and share 3 high-impact wins from the past quarter",
                    isCompleted: false
                ),
                Milestone(
                    id: "ms-012",
                    title: "Have career development conversation with direct manager",
                    isCompleted: false
                ),
                Milestone(
                    id: "ms-013",
                    title: "Build a 90-day impact plan for VP-level responsibilities",
                    isCompleted: false
                )
            ],
            relatedSessionIds: [],
            createdAt: calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now,
            updatedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now
        )

        return [goal1, goal2, goal3]
    }
}
