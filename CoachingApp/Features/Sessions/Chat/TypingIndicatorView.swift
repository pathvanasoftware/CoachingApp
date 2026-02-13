import SwiftUI

struct TypingIndicatorView: View {
    let persona: CoachingPersonaType
    @State private var animationPhase: Int = 0

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            PersonaAvatar(persona: persona, size: 28)

            HStack(spacing: AppTheme.Spacing.xs) {
                Text("Coach is thinking")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(persona.accentColor)
                            .frame(width: 6, height: 6)
                            .offset(y: animationPhase == index ? -4 : 0)
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        withAnimation(
            .easeInOut(duration: 0.35)
            .repeatForever(autoreverses: true)
        ) {
            animationPhase = 0
        }

        // Stagger the dots
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(
                .easeInOut(duration: 0.35)
                .repeatForever(autoreverses: true)
            ) {
                animationPhase = 1
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(
                .easeInOut(duration: 0.35)
                .repeatForever(autoreverses: true)
            ) {
                animationPhase = 2
            }
        }
    }
}

// MARK: - Preview

#Preview("Direct Challenger") {
    TypingIndicatorView(persona: .directChallenger)
        .padding()
}

#Preview("Supportive Strategist") {
    TypingIndicatorView(persona: .supportiveStrategist)
        .padding()
}
