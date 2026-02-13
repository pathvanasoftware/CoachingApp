import SwiftUI

struct CoachingCard: View {
    let title: String
    var subtitle: String?
    var icon: String?
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
                }

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(title)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(AppFonts.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Spacer()

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        CoachingCard(
            title: "Start Session",
            subtitle: "Begin a coaching conversation",
            icon: "bubble.left.fill"
        ) {}

        CoachingCard(
            title: "View Goals",
            subtitle: "Track your progress",
            icon: "target"
        )
    }
    .padding()
}
