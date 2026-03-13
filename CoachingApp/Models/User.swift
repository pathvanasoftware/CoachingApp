import Foundation

enum RoleLevel: String, Codable, CaseIterable, Identifiable {
    case individualContributor = "individual_contributor"
    case manager = "manager"
    case director = "director"
    case vp = "vp"
    case cSuite = "c_suite"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .individualContributor: return "Individual Contributor"
        case .manager: return "Manager"
        case .director: return "Director"
        case .vp: return "VP / SVP"
        case .cSuite: return "C-Suite / Founder"
        }
    }

    var coachingFocus: [String] {
        switch self {
        case .individualContributor:
            return ["Personal impact", "Skill development", "Visibility", "Influence without authority"]
        case .manager:
            return ["Team performance", "Direct reports", "Execution", "Managing up"]
        case .director:
            return ["Cross-functional alignment", "Manager-of-managers", "Strategic initiatives"]
        case .vp:
            return ["Business outcomes", "P&L responsibility", "Org strategy", "Executive presence"]
        case .cSuite:
            return ["Company strategy", "Board relations", "Industry positioning", "Culture & values"]
        }
    }
}

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
    var roleLevel: RoleLevel?
    var onboardingProfile: OnboardingProfile?
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case organizationId = "organization_id"
        case seatTier = "seat_tier"
        case preferredPersona = "preferred_persona"
        case preferredInputMode = "preferred_input_mode"
        case hasCompletedOnboarding = "has_completed_onboarding"
        case roleLevel = "role_level"
        case onboardingProfile = "onboarding_profile"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String = UUID().uuidString,
        email: String,
        fullName: String? = nil,
        organizationId: String? = nil,
        seatTier: SeatTier = .starter,
        preferredPersona: CoachingPersonaType = .directChallenger,
        preferredInputMode: InputMode = .text,
        hasCompletedOnboarding: Bool = false,
        roleLevel: RoleLevel? = nil,
        onboardingProfile: OnboardingProfile? = nil,
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
        self.roleLevel = roleLevel
        self.onboardingProfile = onboardingProfile
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
