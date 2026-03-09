import Foundation

// MARK: - Goal Service Protocol

protocol GoalServiceProtocol: Sendable {
    func fetchGoals(userId: String) async throws -> [Goal]
    func createGoal(goal: Goal) async throws -> Goal
    func updateGoal(goal: Goal) async throws -> Goal
    func deleteGoal(goalId: String) async throws
    func addMilestone(goalId: String, milestone: Milestone) async throws -> Goal
    func toggleMilestone(goalId: String, milestoneId: String) async throws -> Goal
}

// MARK: - Request DTOs

private struct CreateGoalRequest: Codable {
    let title: String
    let description: String
    let status: String
    let progress: Double
    let targetDate: Date?
    let milestones: [MilestoneDTO]
    let relatedSessionIds: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case status
        case progress
        case targetDate = "target_date"
        case milestones
        case relatedSessionIds = "related_session_ids"
    }
}

private struct UpdateGoalRequest: Codable {
    let title: String
    let description: String
    let status: String
    let progress: Double
    let targetDate: Date?
    let milestones: [MilestoneDTO]
    let relatedSessionIds: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case status
        case progress
        case targetDate = "target_date"
        case milestones
        case relatedSessionIds = "related_session_ids"
    }
}

private struct MilestoneDTO: Codable {
    let id: String
    let title: String
    let isCompleted: Bool
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
    }

    init(from milestone: Milestone) {
        self.id = milestone.id
        self.title = milestone.title
        self.isCompleted = milestone.isCompleted
        self.completedAt = milestone.completedAt
    }
}

// MARK: - Goal Service

final class GoalService: GoalServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let apiClient: APIClient

    // MARK: - Init

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        self.apiClient.authTokenProvider = {
            KeychainService.loadAccessToken()
        }
    }

    // MARK: - Fetch Goals

    func fetchGoals(userId _: String) async throws -> [Goal] {
        let goals: [Goal] = try await apiClient.get(path: "/goals", queryItems: nil)

        return goals
    }

    // MARK: - Create Goal

    func createGoal(goal: Goal) async throws -> Goal {
        let request = CreateGoalRequest(
            title: goal.title,
            description: goal.description,
            status: goal.status.rawValue,
            progress: goal.progress,
            targetDate: goal.targetDate,
            milestones: goal.milestones.map { MilestoneDTO(from: $0) },
            relatedSessionIds: goal.relatedSessionIds
        )

        let created: Goal = try await apiClient.post(
            path: "/goals",
            body: request
        )

        return created
    }

    // MARK: - Update Goal

    func updateGoal(goal: Goal) async throws -> Goal {
        let request = UpdateGoalRequest(
            title: goal.title,
            description: goal.description,
            status: goal.status.rawValue,
            progress: goal.progress,
            targetDate: goal.targetDate,
            milestones: goal.milestones.map { MilestoneDTO(from: $0) },
            relatedSessionIds: goal.relatedSessionIds
        )

        let updated: Goal = try await apiClient.put(
            path: "/goals/\(goal.id)",
            body: request
        )

        return updated
    }

    // MARK: - Delete Goal

    func deleteGoal(goalId: String) async throws {
        try await apiClient.delete(path: "/goals/\(goalId)")
    }

    // MARK: - Add Milestone

    func addMilestone(goalId: String, milestone: Milestone) async throws -> Goal {
        var goal: Goal = try await apiClient.get(path: "/goals/\(goalId)", queryItems: nil)

        // Append the new milestone
        goal.milestones.append(milestone)

        // Update the goal
        return try await updateGoal(goal: goal)
    }

    // MARK: - Toggle Milestone

    func toggleMilestone(goalId: String, milestoneId: String) async throws -> Goal {
        var goal: Goal = try await apiClient.get(path: "/goals/\(goalId)", queryItems: nil)

        // Find and toggle the milestone
        guard let index = goal.milestones.firstIndex(where: { $0.id == milestoneId }) else {
            throw GoalServiceError.milestoneNotFound
        }

        goal.milestones[index].isCompleted.toggle()
        goal.milestones[index].completedAt = goal.milestones[index].isCompleted ? Date() : nil

        // Recalculate progress
        let completedCount = goal.milestones.filter { $0.isCompleted }.count
        goal.progress = goal.milestones.isEmpty ? 0 : Double(completedCount) / Double(goal.milestones.count)

        // Update the goal
        return try await updateGoal(goal: goal)
    }
}

// MARK: - Goal Service Error

enum GoalServiceError: Error, LocalizedError {
    case goalNotFound
    case milestoneNotFound
    case updateFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .goalNotFound:
            return "The goal was not found."
        case .milestoneNotFound:
            return "The milestone was not found."
        case .updateFailed:
            return "Failed to update the goal."
        case .deleteFailed:
            return "Failed to delete the goal."
        }
    }
}
