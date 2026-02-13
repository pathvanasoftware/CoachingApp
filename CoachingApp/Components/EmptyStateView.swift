import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String?
    var buttonAction: (() -> Void)?

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.textTertiary)

            Text(title)
                .font(AppFonts.title2)
                .foregroundStyle(AppTheme.textPrimary)

            Text(message)
                .font(AppFonts.body)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xl)

            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .primaryButtonStyle()
                }
                .padding(.horizontal, AppTheme.Spacing.xxl)
                .padding(.top, AppTheme.Spacing.sm)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "target",
        title: "No Goals Yet",
        message: "Set your first goal to start tracking progress.",
        buttonTitle: "Add Goal"
    ) {}
}
