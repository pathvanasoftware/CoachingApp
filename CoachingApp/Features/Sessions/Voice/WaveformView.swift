import SwiftUI

struct WaveformView: View {
    let isActive: Bool
    var amplitude: CGFloat

    private let barCount = 7
    private let minBarHeight: CGFloat = 8
    private let maxBarHeight: CGFloat = 40
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 4

    @State private var barHeights: [CGFloat] = Array(repeating: 8, count: 7)

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(barGradient)
                    .frame(width: barWidth, height: barHeights[index])
            }
        }
        .frame(height: maxBarHeight)
        .onChange(of: isActive) { _, active in
            if active {
                startAnimating()
            } else {
                resetBars()
            }
        }
        .onChange(of: amplitude) { _, newAmplitude in
            if isActive {
                updateBars(with: newAmplitude)
            }
        }
        .onAppear {
            if isActive {
                startAnimating()
            }
        }
    }

    // MARK: - Gradient

    private var barGradient: LinearGradient {
        LinearGradient(
            colors: isActive
                ? [AppTheme.primary, AppTheme.secondary]
                : [AppTheme.textTertiary, AppTheme.textTertiary],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    // MARK: - Animation

    private func startAnimating() {
        updateBars(with: amplitude)
    }

    private func updateBars(with targetAmplitude: CGFloat) {
        let clamped = max(0, min(1, targetAmplitude))
        let effectiveMax = minBarHeight + (maxBarHeight - minBarHeight) * clamped

        withAnimation(.easeInOut(duration: 0.15)) {
            barHeights = (0..<barCount).map { index in
                // Create a natural waveform shape: center bars are taller
                let centerDistance = abs(CGFloat(index) - CGFloat(barCount - 1) / 2.0)
                let centerFactor = 1.0 - (centerDistance / (CGFloat(barCount) / 2.0)) * 0.4
                let randomFactor = CGFloat.random(in: 0.6...1.0)
                let height = effectiveMax * centerFactor * randomFactor
                return max(minBarHeight, height)
            }
        }
    }

    private func resetBars() {
        withAnimation(.easeInOut(duration: 0.3)) {
            barHeights = Array(repeating: minBarHeight, count: barCount)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        VStack {
            Text("Inactive")
                .font(AppFonts.caption)
            WaveformView(isActive: false, amplitude: 0)
        }

        VStack {
            Text("Active - Low")
                .font(AppFonts.caption)
            WaveformView(isActive: true, amplitude: 0.3)
        }

        VStack {
            Text("Active - High")
                .font(AppFonts.caption)
            WaveformView(isActive: true, amplitude: 0.9)
        }
    }
    .padding()
}
