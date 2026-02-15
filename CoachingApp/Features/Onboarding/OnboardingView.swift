import SwiftUI

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel

    init(appState: AppState) {
        self._viewModel = State(initialValue: OnboardingViewModel(appState: appState))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top actions
            HStack {
                Spacer()
                Button("Skip") {
                    viewModel.completeOnboarding()
                }
                .font(AppFonts.subheadline)
                .foregroundStyle(AppTheme.primary)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.sm)

            // Progress bar
            progressBar
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, AppTheme.Spacing.md)

            // Step content
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation buttons
            navigationButtons
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.lg)
        }
        .background(AppTheme.background)
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Step indicator
            HStack {
                Text(viewModel.currentStep.title)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Text("Step \(viewModel.currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            // Progress track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.secondaryBackground)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.primary)
                        .frame(
                            width: geometry.size.width * viewModel.currentStep.progressValue,
                            height: 4
                        )
                        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        TabView(selection: Binding(
            get: { viewModel.currentStep },
            set: { viewModel.currentStep = $0 }
        )) {
            WelcomeView()
                .tag(OnboardingStep.welcome)

            AssessmentView(viewModel: viewModel)
                .tag(OnboardingStep.assessment)

            InputModePreferenceView(
                selectedMode: Binding(
                    get: { viewModel.onboardingData.preferredInputMode },
                    set: { viewModel.onboardingData.preferredInputMode = $0 }
                )
            )
            .tag(OnboardingStep.inputMode)

            PersonaSelectionView(
                selectedPersona: Binding(
                    get: { viewModel.onboardingData.selectedPersona },
                    set: { viewModel.onboardingData.selectedPersona = $0 }
                )
            )
            .tag(OnboardingStep.personaSelection)

            FirstGoalSetupView(viewModel: viewModel)
                .tag(OnboardingStep.firstGoal)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .interactiveDismissDisabled()
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Back button
            if !viewModel.isFirstStep {
                Button {
                    viewModel.previousStep()
                } label: {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .secondaryButtonStyle()
                }
            }

            // Next / Complete button
            Button {
                viewModel.nextStep()
            } label: {
                HStack(spacing: AppTheme.Spacing.xs) {
                    if viewModel.isCompleting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(viewModel.nextButtonTitle)
                        if !viewModel.isLastStep {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                .primaryButtonStyle()
            }
            .disabled(!viewModel.canProceed || viewModel.isCompleting)
            .opacity(viewModel.canProceed ? 1 : 0.6)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(appState: AppState())
}
