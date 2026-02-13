import SwiftUI

struct PersonaSettingsView: View {
    @Bindable var viewModel: ProfileViewModel

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
    }

    // MARK: - Persona Row

    private func personaRow(_ persona: CoachingPersonaType) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.updatePersona(persona)
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

                if viewModel.selectedPersona == persona {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            viewModel.selectedPersona == persona
                ? persona.accentColor.opacity(0.08)
                : Color.clear
        )
    }

    // MARK: - Helpers

    private var selectedPersonaDescription: String? {
        viewModel.selectedPersona.description
    }
}

#Preview {
    NavigationStack {
        PersonaSettingsView(
            viewModel: ProfileViewModel(appState: AppState())
        )
    }
}
