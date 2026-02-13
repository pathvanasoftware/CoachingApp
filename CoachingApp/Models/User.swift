import Foundation

struct User: Identifiable, Codable {
    let id: String
    var email: String
    var fullName: String
    var organizationId: String?
    var seatTier: SeatTier
    var preferredPersona: CoachingPersonaType
    var preferredInputMode: InputMode
    var hasCompletedOnboarding: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        email: String,
        fullName: String,
        organizationId: String? = nil,
        seatTier: SeatTier = .starter,
        preferredPersona: CoachingPersonaType = .directChallenger,
        preferredInputMode: InputMode = .text,
        hasCompletedOnboarding: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.organizationId = organizationId
        self.seatTier = seatTier
        self.preferredPersona = preferredPersona
        self.preferredInputMode = preferredInputMode
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum SeatTier: String, Codable, CaseIterable {
    case starter = "starter"
    case professional = "professional"
    case executive = "executive"

    var displayName: String {
        switch self {
        case .starter: return "Starter"
        case .professional: return "Professional"
        case .executive: return "Executive"
        }
    }

    var dailySessionLimit: Int {
        switch self {
        case .starter: return 5
        case .professional: return 15
        case .executive: return 50
        }
    }
}

struct Organization: Identifiable, Codable {
    let id: String
    var name: String
    var logoURL: String?
    var totalSeats: Int
    var usedSeats: Int
    var createdAt: Date
}

enum InputMode: String, Codable, CaseIterable {
    case text = "text"
    case voice = "voice"
    case both = "both"

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .voice: return "Voice"
        case .both: return "Both"
        }
    }

    var icon: String {
        switch self {
        case .text: return "keyboard"
        case .voice: return "mic.fill"
        case .both: return "text.and.command.macwindow"
        }
    }
}
