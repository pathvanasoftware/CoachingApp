import Foundation

enum SubscriptionPlan: String, Codable, CaseIterable, Identifiable {
    case free
    case pro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Ascendra Pro"
        }
    }

    var badgeTitle: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        }
    }

    var priceLine: String {
        switch self {
        case .free: return "$0"
        case .pro: return "$29/mo or $249/yr"
        }
    }

    var summary: String {
        switch self {
        case .free:
            return "A focused entry point for trying executive coaching with a lighter toolkit."
        case .pro:
            return "Full premium executive coaching with richer interaction and deeper continuity."
        }
    }

    var featureHighlights: [String] {
        switch self {
        case .free:
            return [
                "Core AI executive coaching",
                "One coaching persona",
                "Text-based guidance"
            ]
        case .pro:
            return [
                "Voice coaching access",
                "Session summaries",
                "All coaching personas"
            ]
        }
    }

    var includesVoice: Bool {
        self == .pro
    }

    var includesSessionSummary: Bool {
        self == .pro
    }

    func supports(persona: CoachingPersonaType) -> Bool {
        switch self {
        case .free:
            return persona == .directChallenger
        case .pro:
            return true
        }
    }
}

struct User: Identifiable, Codable {
    let id: String
    var email: String
    var fullName: String?
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
        fullName: String? = nil,
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

    var subscriptionPlan: SubscriptionPlan {
        switch self {
        case .starter:
            return .free
        case .professional, .executive:
            return .pro
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

struct EntitlementSnapshot: Codable {
    let seatTier: String
    let dailySessionLimit: Int
    let canUseVoice: Bool
    let canUseSessionSummary: Bool
    let allowedPersonas: [String]?
    let sessionsStartedToday: Int
    let remainingSessionsToday: Int

    enum CodingKeys: String, CodingKey {
        case seatTier = "seat_tier"
        case dailySessionLimit = "daily_session_limit"
        case canUseVoice = "can_use_voice"
        case canUseSessionSummary = "can_use_session_summary"
        case allowedPersonas = "allowed_personas"
        case sessionsStartedToday = "sessions_started_today"
        case remainingSessionsToday = "remaining_sessions_today"
    }

    var resolvedSeatTier: SeatTier {
        SeatTier(rawValue: seatTier) ?? .starter
    }
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
