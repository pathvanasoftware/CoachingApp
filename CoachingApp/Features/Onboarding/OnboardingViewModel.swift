import Foundation
import SwiftUI

@Observable
final class OnboardingViewModel {

    // MARK: - State

    var currentStep: OnboardingStep = .welcome
    var onboardingData = OnboardingData()
    var isCompleting: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let appState: AppState

    // MARK: - Init

    init(appState: AppState) {
        self.appState = appState

        // Pre-fill name if available from auth
        if let name = appState.currentUserName {
            onboardingData.userName = name
        }
    }

    // MARK: - Computed Properties

    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true

        case .assessment:
            // Require at least answers for all questions
            let answeredIds = Set(onboardingData.assessmentAnswers.map { $0.questionId })
            let requiredIds = Set(OnboardingAssessment.questions.map { $0.id })
            return requiredIds.isSubset(of: answeredIds)

        case .inputMode:
            // Always valid — has a default selection
            return true

        case .personaSelection:
            // Always valid — has a default selection
            return true

        case .firstGoal:
            // Can always proceed (goal is optional / can skip)
            return true
        }
    }

    var isFirstStep: Bool {
        currentStep == .welcome
    }

    var isLastStep: Bool {
        currentStep == .firstGoal
    }

    var nextButtonTitle: String {
        if isLastStep {
            return onboardingData.firstGoalTitle.isEmpty ? "Skip & Finish" : "Finish Setup"
        }
        return "Continue"
    }

    // MARK: - Navigation

    func nextStep() {
        guard canProceed else { return }

        if isLastStep {
            completeOnboarding()
            return
        }

        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex + 1 < OnboardingStep.allCases.count else {
            return
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = OnboardingStep.allCases[currentIndex + 1]
        }
    }

    func previousStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else {
            return
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = OnboardingStep.allCases[currentIndex - 1]
        }
    }

    func skipGoal() {
        onboardingData.firstGoalTitle = ""
        onboardingData.firstGoalDescription = ""
        completeOnboarding()
    }

    // MARK: - Complete Onboarding

    func completeOnboarding() {
        isCompleting = true

        // Apply onboarding selections to AppState
        appState.preferredInputMode = onboardingData.preferredInputMode
        appState.selectedPersona = onboardingData.selectedPersona

        if !onboardingData.userName.isEmpty {
            appState.currentUserName = onboardingData.userName
        }

        // Mark onboarding as complete
        appState.completeOnboarding()

        isCompleting = false
    }

    // MARK: - Assessment Helpers

    func setAnswer(for question: AssessmentQuestion, answer: String) {
        // Remove existing answer for this question if present
        onboardingData.assessmentAnswers.removeAll { $0.questionId == question.id }

        let assessmentAnswer = AssessmentAnswer(
            questionId: question.id,
            question: question.question,
            answer: answer
        )
        onboardingData.assessmentAnswers.append(assessmentAnswer)

        // Auto-set persona based on coaching style preference
        if question.id == "coaching_style" {
            if answer.lowercased().contains("direct") {
                onboardingData.selectedPersona = .directChallenger
            } else if answer.lowercased().contains("supportive") {
                onboardingData.selectedPersona = .supportiveStrategist
            }
        }

        // Store role if it's the role question
        if question.id == "role" {
            onboardingData.userRole = answer
        }
    }

    func answer(for questionId: String) -> String? {
        onboardingData.assessmentAnswers.first { $0.questionId == questionId }?.answer
    }

    // MARK: - Goal Suggestions

    var suggestedGoals: [(title: String, description: String)] {
        let challengeAnswer = answer(for: "challenge") ?? ""
        let goalAreaAnswer = answer(for: "goal_area") ?? ""

        var suggestions: [(title: String, description: String)] = []

        // Based on challenge answer
        if challengeAnswer.contains("politics") {
            suggestions.append((
                title: "Navigate Organizational Politics",
                description: "Build strategic relationships and influence without authority across the organization."
            ))
        }
        if challengeAnswer.contains("team") {
            suggestions.append((
                title: "Build a High-Performing Team",
                description: "Develop team dynamics, accountability, and performance culture."
            ))
        }
        if challengeAnswer.contains("presence") || challengeAnswer.contains("communication") {
            suggestions.append((
                title: "Strengthen Executive Presence",
                description: "Communicate with clarity and confidence in high-stakes situations."
            ))
        }
        if challengeAnswer.contains("career") || challengeAnswer.contains("promotion") {
            suggestions.append((
                title: "Accelerate Career Growth",
                description: "Position yourself strategically for your next role or promotion."
            ))
        }

        // Based on goal area if we need more
        if suggestions.count < 3 {
            if goalAreaAnswer.contains("Leadership") && !suggestions.contains(where: { $0.title.contains("Leadership") }) {
                suggestions.append((
                    title: "Improve Leadership Effectiveness",
                    description: "Develop your leadership style to inspire and drive results."
                ))
            }
            if goalAreaAnswer.contains("Strategic") && !suggestions.contains(where: { $0.title.contains("Strategic") }) {
                suggestions.append((
                    title: "Develop Strategic Thinking",
                    description: "Move from operational execution to strategic vision and planning."
                ))
            }
            if goalAreaAnswer.contains("Communication") && !suggestions.contains(where: { $0.title.contains("Communi") }) {
                suggestions.append((
                    title: "Master Stakeholder Communication",
                    description: "Tailor your communication to different audiences and contexts."
                ))
            }
            if goalAreaAnswer.contains("Confidence") && !suggestions.contains(where: { $0.title.contains("Confidence") }) {
                suggestions.append((
                    title: "Build Confidence in Leadership",
                    description: "Overcome imposter syndrome and lead with authentic confidence."
                ))
            }
        }

        // Default suggestions if none matched
        if suggestions.isEmpty {
            suggestions = [
                ("Improve Leadership Effectiveness", "Develop your leadership style to inspire and drive results."),
                ("Strengthen Communication Skills", "Communicate with clarity and confidence in all settings."),
                ("Accelerate Career Growth", "Position yourself strategically for your next opportunity.")
            ]
        }

        return Array(suggestions.prefix(4))
    }
}
