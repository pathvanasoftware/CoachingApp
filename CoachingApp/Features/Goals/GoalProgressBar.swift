import SwiftUI

struct GoalProgressBar: View {
    let progress: Double
    var style: ProgressStyle = .linear

    enum ProgressStyle {
        case linear
        case circular
    }

    var body: some View {
        switch style {
        case .linear:
            linearProgress
        case .circular:
            circularProgress
        }
    }

    // MARK: - Linear Progress

    private var linearProgress: some View {
        VStack(alignment: .trailing, spacing: AppTheme.Spacing.xs) {
            Text("\(percentageValue)%")
                .font(AppFonts.caption)
                .foregroundStyle(progressColor)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
                        .fill(AppTheme.tertiaryBackground)
                        .frame(height: 8)

                    // Fill
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.full)
                        .fill(progressColor.gradient)
                        .frame(width: max(0, geometry.size.width * clampedProgress), height: 8)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Circular Progress

    private var circularProgress: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(AppTheme.tertiaryBackground, lineWidth: 8)

            // Progress ring
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    progressColor.gradient,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            // Percentage label
            VStack(spacing: 2) {
                Text("\(percentageValue)%")
                    .font(AppFonts.title2)
                    .foregroundStyle(progressColor)

                Text("complete")
                    .font(AppFonts.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }

    // MARK: - Helpers

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var percentageValue: Int {
        Int(clampedProgress * 100)
    }

    private var progressColor: Color {
        switch clampedProgress {
        case 0..<0.33:
            return AppTheme.error
        case 0.33..<0.66:
            return AppTheme.warning
        default:
            return AppTheme.success
        }
    }
}

#Preview("Linear Progress") {
    VStack(spacing: 20) {
        GoalProgressBar(progress: 0.15, style: .linear)
        GoalProgressBar(progress: 0.45, style: .linear)
        GoalProgressBar(progress: 0.80, style: .linear)
        GoalProgressBar(progress: 1.0, style: .linear)
    }
    .padding()
}

#Preview("Circular Progress") {
    HStack(spacing: 30) {
        GoalProgressBar(progress: 0.20, style: .circular)
            .frame(width: 100, height: 100)
        GoalProgressBar(progress: 0.50, style: .circular)
            .frame(width: 100, height: 100)
        GoalProgressBar(progress: 0.85, style: .circular)
            .frame(width: 100, height: 100)
    }
    .padding()
}
