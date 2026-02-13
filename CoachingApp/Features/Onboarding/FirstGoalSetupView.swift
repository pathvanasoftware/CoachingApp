import SwiftUI

struct FirstGoalSetupView: View {
    @Bindable var viewModel: OnboardingViewModel

    @FocusState private var isTitleFocused: Bool
    @FocusState private var isDescriptionFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                // Header
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "target")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.bottom, AppTheme.Spacing.sm)

                    Text("Let's set your\nfirst goal")
                        .font(AppFonts.title2)
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("What would you like to work on first?\nThis helps focus your coaching sessions.")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppTheme.Spacing.lg)

                // Suggested goals
                if !viewModel.suggestedGoals.isEmpty {
                    suggestedGoalsSection
                }

                // Goal input
                goalInputSection

                // Skip option
                Button {
                    viewModel.skipGoal()
                } label: {
                    Text("I'll set this up later")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textTertiary)
                        .underline()
                }
                .padding(.top, AppTheme.Spacing.sm)

                Spacer()
                    .frame(height: AppTheme.Spacing.xxl)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Suggested Goals

    private var suggestedGoalsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Suggested for you")
                .font(AppFonts.caption)
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)

            FlowLayout(spacing: AppTheme.Spacing.sm) {
                ForEach(viewModel.suggestedGoals, id: \.title) { suggestion in
                    let isSelected = viewModel.onboardingData.firstGoalTitle == suggestion.title

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.onboardingData.firstGoalTitle = suggestion.title
                            viewModel.onboardingData.firstGoalDescription = suggestion.description
                            isTitleFocused = false
                            isDescriptionFocused = false
                        }
                    } label: {
                        Text(suggestion.title)
                            .font(AppFonts.subheadline)
                            .foregroundStyle(
                                isSelected ? .white : AppTheme.textPrimary
                            )
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(
                                        isSelected
                                            ? AppTheme.primary
                                            : AppTheme.secondaryBackground
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        isSelected ? AppTheme.primary : AppTheme.textTertiary.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Goal Input

    private var goalInputSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Title
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Goal Title")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)

                TextField("e.g., Improve my executive presence", text: $viewModel.onboardingData.firstGoalTitle)
                    .font(AppFonts.body)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .stroke(
                                isTitleFocused ? AppTheme.primary : AppTheme.textTertiary.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .focused($isTitleFocused)
            }

            // Description
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text("Description (optional)")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .textCase(.uppercase)

                TextEditor(text: $viewModel.onboardingData.firstGoalDescription)
                    .font(AppFonts.body)
                    .scrollContentBackground(.hidden)
                    .padding(AppTheme.Spacing.md)
                    .frame(minHeight: 100)
                    .background(AppTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                            .stroke(
                                isDescriptionFocused ? AppTheme.primary : AppTheme.textTertiary.opacity(0.3),
                                lineWidth: 1
                            )
                    )
                    .focused($isDescriptionFocused)

                if viewModel.onboardingData.firstGoalDescription.isEmpty {
                    Text("Describe what success looks like and why this matters to you.")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
        }
    }
}

// MARK: - Flow Layout

/// A simple horizontal flow layout that wraps items to the next line when they exceed the available width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (
            size: CGSize(width: maxX, height: currentY + lineHeight),
            positions: positions
        )
    }
}

// MARK: - Preview

#Preview {
    FirstGoalSetupView(viewModel: OnboardingViewModel(appState: AppState()))
}
