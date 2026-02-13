import SwiftUI

struct WelcomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xxl) {
                Spacer()
                    .frame(height: AppTheme.Spacing.xl)

                // App icon area
                appIcon

                // Title
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Welcome to")
                        .font(AppFonts.title2)
                        .foregroundStyle(AppTheme.textSecondary)

                    Text("CoachingApp")
                        .font(AppFonts.largeTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                }

                // Subtitle
                Text("Your AI-powered executive coach,\navailable whenever you need guidance.")
                    .font(AppFonts.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.lg)

                // Feature highlights
                VStack(spacing: AppTheme.Spacing.md) {
                    featureRow(
                        icon: "brain.head.profile",
                        title: "AI-Powered Executive Coaching",
                        description: "Personalized coaching grounded in proven leadership methodology"
                    )

                    featureRow(
                        icon: "mic.and.signal.meter",
                        title: "Voice or Text -- Your Choice",
                        description: "Speak naturally or type, whichever fits your moment"
                    )

                    featureRow(
                        icon: "target",
                        title: "Set Goals and Track Progress",
                        description: "Define objectives and measure your growth over time"
                    )

                    featureRow(
                        icon: "checkmark.shield",
                        title: "Backed by Proven Methodology",
                        description: "Built on frameworks used by top executive coaches"
                    )
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                Spacer()
                    .frame(height: AppTheme.Spacing.xl)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - App Icon

    private var appIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)

            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white)
        }
        .shadow(color: AppTheme.primary.opacity(0.3), radius: 16, y: 8)
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 44, height: 44)
                .background(AppTheme.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(description)
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
}
