import Foundation

struct ActionItem: Identifiable, Codable {
    let id: String
    var sessionId: String
    var userId: String
    var title: String
    var description: String
    var isCompleted: Bool
    var dueDate: Date?
    var completedAt: Date?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        userId: String,
        title: String,
        description: String = "",
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.userId = userId
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.createdAt = createdAt
    }

    var isDueToday: Bool {
        guard let dueDate else { return false }
        return dueDate.isToday
    }

    var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }
}
