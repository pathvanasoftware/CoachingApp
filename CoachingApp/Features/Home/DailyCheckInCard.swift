import SwiftUI

struct DailyCheckInCard: View {
    let persona: CoachingPersonaType
    var onStartSession: () -> Void

    @State private var selectedSessionType: SessionType = .checkIn

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Header
            HStack(spacing: AppTheme.Spacing.md) {
                PersonaAvatar(persona: persona, size: 48)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("Ready for a coaching session?")
                        .font(AppFonts.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(persona.displayName)
                        .font(AppFonts.subheadline)
                        .foregroundStyle(persona.accentColor)
                }

                Spacer()
            }

            // Session Type Picker
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Session type")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(SessionType.allCases, id: \.self) { type in
                            sessionTypeChip(type)
                        }
                    }
                }
            }

            // Start Button
            Button(action: onStartSession) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Session")
                }
                .primaryButtonStyle()
            }
            .buttonStyle(.borderless)
        }
        .cardStyle()
    }

    private func sessionTypeChip(_ type: SessionType) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSessionType = type
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: type.icon)
                    .font(AppFonts.caption)
                Text(type.displayName)
                    .font(AppFonts.caption)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(
                selectedSessionType == type
                    ? AppTheme.primary.opacity(0.15)
                    : AppTheme.tertiaryBackground
            )
            .foregroundStyle(
                selectedSessionType == type
                    ? AppTheme.primary
                    : AppTheme.textSecondary
            )
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        selectedSessionType == type
                            ? AppTheme.primary.opacity(0.3)
                            : Color.clear,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DailyCheckInCard(
        persona: .directChallenger,
        onStartSession: {}
    )
    .padding()
}
