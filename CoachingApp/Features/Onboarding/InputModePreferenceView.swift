import SwiftUI

struct InputModePreferenceView: View {
    @Binding var selectedMode: InputMode

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                // Header
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.bottom, AppTheme.Spacing.sm)

                    Text("How would you like\nto interact?")
                        .font(AppFonts.title2)
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("You can change this anytime in settings.")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.top, AppTheme.Spacing.xl)

                // Mode cards
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(InputMode.allCases, id: \.self) { mode in
                        modeCard(for: mode)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                Spacer()
                    .frame(height: AppTheme.Spacing.xl)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Mode Card

    private func modeCard(for mode: InputMode) -> some View {
        let isSelected = selectedMode == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                // Icon
                Image(systemName: mode.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? AppTheme.primary : AppTheme.textSecondary)
                    .frame(width: 56, height: 56)
                    .background(
                        isSelected
                            ? AppTheme.primary.opacity(0.12)
                            : AppTheme.tertiaryBackground
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))

                // Text
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(mode.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(
                            isSelected ? AppTheme.primary : AppTheme.textPrimary
                        )

                    Text(modeDescription(for: mode))
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.primary)
                } else {
                    Circle()
                        .stroke(AppTheme.textTertiary, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .fill(
                        isSelected
                            ? AppTheme.primary.opacity(0.05)
                            : AppTheme.secondaryBackground
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(
                        isSelected ? AppTheme.primary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Descriptions

    private func modeDescription(for mode: InputMode) -> String {
        switch mode {
        case .text:
            return "Type your thoughts and read responses. Great for detailed, reflective sessions."
        case .voice:
            return "Speak naturally and hear responses. Feels like a real coaching conversation."
        case .both:
            return "Switch freely between voice and text within any session. Maximum flexibility."
        }
    }
}

// MARK: - Preview

#Preview {
    InputModePreferenceView(selectedMode: .constant(.text))
}
