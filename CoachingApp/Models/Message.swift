import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: String
    var sessionId: String
    var role: MessageRole
    var content: String
    var timestamp: Date
    var isStreaming: Bool
    var diagnostics: CoachingDiagnostics?
    var status: MessageStatus

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        diagnostics: CoachingDiagnostics? = nil,
        status: MessageStatus = .sent
    ) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.diagnostics = diagnostics
        self.status = status
    }

    var isFromUser: Bool { role == .user }
    var isFromCoach: Bool { role == .assistant }
}

enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

enum MessageStatus: String, Codable {
    case sending = "sending"
    case sent = "sent"
    case failed = "failed"
}

struct CoachingDiagnostics: Codable {
    var styleUsed: String
    var emotionDetected: String
    var goalLink: String
    var goalAnchor: String?
    var goalHierarchySummary: String?
    var progressiveSkillSummary: String?
    var outcomePredictionSummary: String?
    var riskLevel: String?
    var recommendedStyleShift: String?
}
