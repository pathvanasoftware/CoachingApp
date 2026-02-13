import Foundation

struct Goal: Identifiable, Codable {
    let id: String
    var userId: String
    var title: String
    var description: String
    var status: GoalStatus
    var progress: Double
    var targetDate: Date?
    var milestones: [Milestone]
    var relatedSessionIds: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        description: String = "",
        status: GoalStatus = .active,
        progress: Double = 0.0,
        targetDate: Date? = nil,
        milestones: [Milestone] = [],
        relatedSessionIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.status = status
        self.progress = progress
        self.targetDate = targetDate
        self.milestones = milestones
        self.relatedSessionIds = relatedSessionIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var completedMilestones: Int {
        milestones.filter { $0.isCompleted }.count
    }

    var progressPercentage: Int {
        Int(progress * 100)
    }
}

enum GoalStatus: String, Codable, CaseIterable {
    case active = "active"
    case completed = "completed"
    case paused = "paused"
    case archived = "archived"

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        case .paused: return "Paused"
        case .archived: return "Archived"
        }
    }

    var icon: String {
        switch self {
        case .active: return "flame.fill"
        case .completed: return "checkmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .archived: return "archivebox.fill"
        }
    }
}

struct Milestone: Identifiable, Codable {
    let id: String
    var title: String
    var isCompleted: Bool
    var completedAt: Date?

    init(
        id: String = UUID().uuidString,
        title: String,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}
