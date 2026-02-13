import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(AppFonts.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

#Preview {
    LoadingView(message: "Loading your data...")
}
