import Foundation

struct OnboardingData {
    var assessmentAnswers: [AssessmentAnswer] = []
    var preferredInputMode: InputMode = .text
    var selectedPersona: CoachingPersonaType = .directChallenger
    var firstGoalTitle: String = ""
    var firstGoalDescription: String = ""
    var userName: String = ""
    var userRole: String = ""
}

struct AssessmentAnswer: Identifiable {
    let id = UUID()
    let questionId: String
    let question: String
    var answer: String
}

struct AssessmentQuestion: Identifiable {
    let id: String
    let question: String
    let subtitle: String
    let options: [String]?

    var isFreeText: Bool { options == nil }
}

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case assessment = 1
    case inputMode = 2
    case personaSelection = 3
    case firstGoal = 4

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .assessment: return "About You"
        case .inputMode: return "Interaction Style"
        case .personaSelection: return "Your Coach"
        case .firstGoal: return "First Goal"
        }
    }

    var progressValue: Double {
        Double(rawValue + 1) / Double(Self.allCases.count)
    }
}

enum OnboardingAssessment {
    static let questions: [AssessmentQuestion] = [
        AssessmentQuestion(
            id: "role",
            question: "What best describes your current role?",
            subtitle: "This helps us tailor coaching to your level",
            options: [
                "Individual Contributor / Senior IC",
                "Manager / Team Lead",
                "Director / Senior Manager",
                "VP / SVP",
                "C-Suite / Founder"
            ]
        ),
        AssessmentQuestion(
            id: "experience",
            question: "How many years of leadership experience do you have?",
            subtitle: "Including both formal and informal leadership",
            options: [
                "Less than 2 years",
                "2-5 years",
                "5-10 years",
                "10-20 years",
                "20+ years"
            ]
        ),
        AssessmentQuestion(
            id: "challenge",
            question: "What's your biggest leadership challenge right now?",
            subtitle: "We'll focus our coaching around this",
            options: [
                "Navigating organizational politics",
                "Building and leading a high-performing team",
                "Executive presence and communication",
                "Career trajectory and next-level promotion",
                "Managing up and stakeholder relationships",
                "Work-life balance and avoiding burnout"
            ]
        ),
        AssessmentQuestion(
            id: "coaching_style",
            question: "What coaching style do you prefer?",
            subtitle: "This helps us match you with the right persona",
            options: [
                "Direct and challenging — tell me what I need to hear",
                "Supportive and strategic — help me think it through",
                "A mix of both depending on the situation"
            ]
        ),
        AssessmentQuestion(
            id: "goal_area",
            question: "What area would you most like to grow in?",
            subtitle: "We'll set your first goal around this",
            options: [
                "Leadership effectiveness",
                "Strategic thinking",
                "Communication skills",
                "Team development",
                "Career advancement",
                "Confidence and executive presence"
            ]
        )
    ]
}
