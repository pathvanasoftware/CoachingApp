import Foundation

@Observable
final class GoalsViewModel {
    var goals: [Goal] = []
    var selectedFilter: GoalStatus? = .active
    var isLoading: Bool = false
    var showingAddGoal: Bool = false
    var errorMessage: String?

    private let goalService: GoalServiceProtocol

    init(goalService: GoalServiceProtocol = MockGoalService()) {
        self.goalService = goalService
    }

    // MARK: - Computed Properties

    var filteredGoals: [Goal] {
        guard let filter = selectedFilter else {
            return goals
        }
        return goals.filter { $0.status == filter }
    }

    var activeGoalsCount: Int {
        goals.filter { $0.status == .active }.count
    }

    var completedGoalsCount: Int {
        goals.filter { $0.status == .completed }.count
    }

    // MARK: - Actions

    func loadGoals() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            goals = try await goalService.fetchGoals(userId: "mock-user-001")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addGoal(title: String, description: String, targetDate: Date?, milestones: [String]) async {
        let newMilestones = milestones.map { Milestone(title: $0) }
        let goal = Goal(
            userId: "mock-user-001",
            title: title,
            description: description,
            targetDate: targetDate,
            milestones: newMilestones
        )

        do {
            let created = try await goalService.createGoal(goal: goal)
            goals.append(created)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateGoal(_ goal: Goal) async {
        do {
            let updated = try await goalService.updateGoal(goal: goal)
            if let index = goals.firstIndex(where: { $0.id == updated.id }) {
                goals[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteGoal(_ goal: Goal) async {
        do {
            try await goalService.deleteGoal(goalId: goal.id)
            goals.removeAll { $0.id == goal.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleMilestone(goalId: String, milestoneId: String) async {
        do {
            let updated = try await goalService.toggleMilestone(goalId: goalId, milestoneId: milestoneId)
            if let index = goals.firstIndex(where: { $0.id == updated.id }) {
                goals[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
