import SwiftUI

struct CoachingStyleSelectionView: View {
    @Binding var selectedStyle: CoachingStyle

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.bottom, AppTheme.Spacing.sm)

                    Text("Choose your\ncoaching style")
                        .font(AppFonts.title2)
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("You can change this anytime in chat.")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppTheme.Spacing.xl)

                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(CoachingStyle.allCases) { style in
                        styleCard(for: style)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                Spacer().frame(height: AppTheme.Spacing.xl)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func styleCard(for style: CoachingStyle) -> some View {
        let isSelected = selectedStyle == style

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedStyle = style
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: icon(for: style))
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? AppTheme.primary : AppTheme.textSecondary)
                    .frame(width: 48, height: 48)
                    .background(
                        isSelected ? AppTheme.primary.opacity(0.12) : AppTheme.tertiaryBackground
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(style.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(isSelected ? AppTheme.primary : AppTheme.textPrimary)

                    Text(description(for: style))
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .fill(isSelected ? AppTheme.primary.opacity(0.05) : AppTheme.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(isSelected ? AppTheme.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func icon(for style: CoachingStyle) -> String {
        switch style {
        case .auto: return "sparkles"
        case .directive: return "bolt.fill"
        case .facilitative: return "questionmark.bubble.fill"
        case .supportive: return "heart.fill"
        case .strategic: return "chessboard.fill"
        }
    }

    private func description(for style: CoachingStyle) -> String {
        switch style {
        case .auto:
            return "Model picks the best style for each message."
        case .directive:
            return "Direct, clear, and action-oriented guidance."
        case .facilitative:
            return "Question-led exploration to surface your own insight."
        case .supportive:
            return "Empathetic and confidence-building coaching tone."
        case .strategic:
            return "Framework-driven planning and trade-off analysis."
        }
    }
}

#Preview {
    CoachingStyleSelectionView(selectedStyle: .constant(.auto))
}
