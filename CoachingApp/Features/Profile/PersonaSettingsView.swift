import SwiftUI

struct PersonaSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showSubscriptionSheet = false

    var body: some View {
        List {
            ForEach(CoachingPersonaType.allCases) { persona in
                personaRow(persona)
            }

            // Selected Persona Description
            if let selectedDescription = selectedPersonaDescription {
                Section("About This Persona") {
                    Text(selectedDescription)
                        .font(AppFonts.body)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .navigationTitle("Coaching Persona")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSubscriptionSheet) {
            SubscriptionView(highlightedFeature: "the supportive strategist persona")
                .environment(appState)
        }
    }

    // MARK: - Persona Row

    private func personaRow(_ persona: CoachingPersonaType) -> some View {
        Button {
            if appState.subscriptionPlan.supports(persona: persona) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.selectedPersona = persona
                }
            } else {
                showSubscriptionSheet = true
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                PersonaAvatar(persona: persona, size: 48)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(persona.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(persona.tagline)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if appState.selectedPersona == persona {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primary)
                } else if !appState.subscriptionPlan.supports(persona: persona) {
                    Label("Pro", systemImage: "lock.fill")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.warning)
                }
            }
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            appState.selectedPersona == persona
                ? persona.accentColor.opacity(0.08)
                : Color.clear
        )
    }

    // MARK: - Helpers

    private var selectedPersonaDescription: String? {
        appState.selectedPersona.description
    }
}

#Preview {
    NavigationStack {
        PersonaSettingsView()
    }
    .environment(AppState())
}
