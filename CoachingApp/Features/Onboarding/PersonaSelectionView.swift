import SwiftUI

struct PersonaSelectionView: View {
    @Binding var selectedPersona: CoachingPersonaType

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                // Header
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Choose your\ncoaching style")
                        .font(AppFonts.title2)
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Each persona has a distinct approach.\nYou can switch anytime.")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppTheme.Spacing.lg)

                // Persona cards
                VStack(spacing: AppTheme.Spacing.md) {
                    ForEach(CoachingPersonaType.allCases) { persona in
                        personaCard(for: persona)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                Spacer()
                    .frame(height: AppTheme.Spacing.xl)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Persona Card

    private func personaCard(for persona: CoachingPersonaType) -> some View {
        let isSelected = selectedPersona == persona

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPersona = persona
            }
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                // Top row: avatar, name, checkmark
                HStack(spacing: AppTheme.Spacing.md) {
                    PersonaAvatar(persona: persona, size: 56)

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(persona.displayName)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(persona.tagline)
                            .font(AppFonts.caption)
                            .foregroundStyle(persona.accentColor)
                            .lineLimit(2)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(persona.accentColor)
                    }
                }

                // Description
                Text(persona.description)
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Sample message
                sampleMessage(for: persona)
            }
            .padding(AppTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .fill(AppTheme.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                    .stroke(
                        isSelected ? persona.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .modifier(CardShadow())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sample Message

    private func sampleMessage(for persona: CoachingPersonaType) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textTertiary)

                Text("Sample response")
                    .font(AppFonts.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Text(sampleText(for: persona))
                .font(AppFonts.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .italic()
                .lineLimit(3)
                .padding(AppTheme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm)
                        .fill(AppTheme.coachBubble)
                )
        }
    }

    private func sampleText(for persona: CoachingPersonaType) -> String {
        switch persona {
        case .directChallenger:
            return "\"You said you want to be more strategic, but you just described spending 80% of your time in the weeds. What's actually stopping you from delegating those tasks?\""
        case .supportiveStrategist:
            return "\"It sounds like you're carrying a lot right now. I'm curious — when you imagine having delegated those tasks successfully, how does that change your day-to-day experience?\""
        }
    }
}

// MARK: - Preview

#Preview {
    PersonaSelectionView(selectedPersona: .constant(.directChallenger))
}
