import SwiftUI

struct SessionTimerView: View {
    let elapsedSeconds: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            Image(systemName: "clock.fill")
                .font(.system(size: 9))

            Text(formattedTime)
                .font(AppFonts.caption2)
                .monospacedDigit()
        }
        .foregroundStyle(AppTheme.textSecondary)
    }

    // MARK: - Formatting

    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview("Short Session") {
    SessionTimerView(elapsedSeconds: 125)
}

#Preview("Long Session") {
    SessionTimerView(elapsedSeconds: 3661)
}
