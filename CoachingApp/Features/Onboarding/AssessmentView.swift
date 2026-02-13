import SwiftUI

struct AssessmentView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var currentQuestionIndex: Int = 0
    @State private var freeTextInputs: [String: String] = [:]

    private let questions = OnboardingAssessment.questions

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Header
            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Tell us about yourself")
                    .font(AppFonts.title2)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.top, AppTheme.Spacing.md)

            // Question dots
            questionDots

            // Current question
            if currentQuestionIndex < questions.count {
                questionView(for: questions[currentQuestionIndex])
                    .id(currentQuestionIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }

            Spacer()

            // Question navigation
            questionNavigation
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .animation(.easeInOut(duration: 0.3), value: currentQuestionIndex)
    }

    // MARK: - Question Dots

    private var questionDots: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(0..<questions.count, id: \.self) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: 8, height: 8)
                    .onTapGesture {
                        // Allow navigating to answered questions or current
                        if index <= currentQuestionIndex || viewModel.answer(for: questions[index].id) != nil {
                            currentQuestionIndex = index
                        }
                    }
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if index == currentQuestionIndex {
            return AppTheme.primary
        } else if viewModel.answer(for: questions[index].id) != nil {
            return AppTheme.success
        } else {
            return AppTheme.textTertiary.opacity(0.3)
        }
    }

    // MARK: - Question View

    @ViewBuilder
    private func questionView(for question: AssessmentQuestion) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(question.question)
                    .font(AppFonts.title3)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(question.subtitle)
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if question.isFreeText {
                freeTextInput(for: question)
            } else if let options = question.options {
                optionsView(for: question, options: options)
            }
        }
    }

    // MARK: - Options View

    private func optionsView(for question: AssessmentQuestion, options: [String]) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(options, id: \.self) { option in
                    let isSelected = viewModel.answer(for: question.id) == option

                    Button {
                        viewModel.setAnswer(for: question, answer: option)

                        // Auto-advance after selection with a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if currentQuestionIndex < questions.count - 1 {
                                currentQuestionIndex += 1
                            }
                        }
                    } label: {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Text(option)
                                .font(AppFonts.body)
                                .foregroundStyle(
                                    isSelected ? AppTheme.primary : AppTheme.textPrimary
                                )
                                .multilineTextAlignment(.leading)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.primary)
                                    .font(.system(size: 22))
                            } else {
                                Circle()
                                    .stroke(AppTheme.textTertiary, lineWidth: 1.5)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .fill(
                                    isSelected
                                        ? AppTheme.primary.opacity(0.08)
                                        : AppTheme.secondaryBackground
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .stroke(
                                    isSelected ? AppTheme.primary : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Free Text Input

    private func freeTextInput(for question: AssessmentQuestion) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            TextEditor(
                text: Binding(
                    get: { freeTextInputs[question.id] ?? viewModel.answer(for: question.id) ?? "" },
                    set: { newValue in
                        freeTextInputs[question.id] = newValue
                        viewModel.setAnswer(for: question, answer: newValue)
                    }
                )
            )
            .font(AppFonts.body)
            .scrollContentBackground(.hidden)
            .padding(AppTheme.Spacing.md)
            .frame(minHeight: 120)
            .background(AppTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                    .stroke(AppTheme.textTertiary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Question Navigation

    private var questionNavigation: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            if currentQuestionIndex > 0 {
                Button {
                    currentQuestionIndex -= 1
                } label: {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            if currentQuestionIndex < questions.count - 1 {
                Button {
                    currentQuestionIndex += 1
                } label: {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.primary)
                }
                .disabled(viewModel.answer(for: questions[currentQuestionIndex].id) == nil)
                .opacity(viewModel.answer(for: questions[currentQuestionIndex].id) != nil ? 1 : 0.4)
            }
        }
        .padding(.bottom, AppTheme.Spacing.sm)
    }
}

// MARK: - Preview

#Preview {
    AssessmentView(viewModel: OnboardingViewModel(appState: AppState()))
}
