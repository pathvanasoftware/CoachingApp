import Foundation

struct CoachingSession: Identifiable, Codable {
    let id: String
    var userId: String
    var persona: CoachingPersonaType
    var sessionType: SessionType
    var inputMode: InputMode
    var startedAt: Date
    var endedAt: Date?
    var summary: String?
    var durationSeconds: Int?
    var messageCount: Int
    var goalIds: [String]

    init(
        id: String = UUID().uuidString,
        userId: String,
        persona: CoachingPersonaType = .directChallenger,
        sessionType: SessionType = .checkIn,
        inputMode: InputMode = .text,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        summary: String? = nil,
        durationSeconds: Int? = nil,
        messageCount: Int = 0,
        goalIds: [String] = []
    ) {
        self.id = id
        self.userId = userId
        self.persona = persona
        self.sessionType = sessionType
        self.inputMode = inputMode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.summary = summary
        self.durationSeconds = durationSeconds
        self.messageCount = messageCount
        self.goalIds = goalIds
    }

    var isActive: Bool { endedAt == nil }

    var formattedDuration: String {
        guard let seconds = durationSeconds else { return "--:--" }
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}

enum SessionType: String, Codable, CaseIterable {
    case checkIn = "check_in"
    case deepDive = "deep_dive"
    case goalReview = "goal_review"
    case freeform = "freeform"

    var displayName: String {
        switch self {
        case .checkIn: return "Check-in"
        case .deepDive: return "Deep Dive"
        case .goalReview: return "Goal Review"
        case .freeform: return "Freeform"
        }
    }

    var icon: String {
        switch self {
        case .checkIn: return "hand.wave.fill"
        case .deepDive: return "arrow.down.circle.fill"
        case .goalReview: return "target"
        case .freeform: return "bubble.left.and.bubble.right.fill"
        }
    }
}
