import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: ProfileViewModel?
    @State private var showingSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            if let viewModel {
                profileContent(viewModel: viewModel)
            } else {
                LoadingView(message: "Loading profile...")
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ProfileViewModel(appState: appState)
            }
        }
    }

    @ViewBuilder
    private func profileContent(viewModel: ProfileViewModel) -> some View {
        List {
            // User Info Section
            userInfoSection(viewModel: viewModel)

            // Coaching Settings
            coachingSettingsSection

            // Account Settings
            accountSection

            // Sign Out
            signOutSection
        }
        .navigationTitle("Profile")
        .confirmationDialog(
            "Sign Out",
            isPresented: $showingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                viewModel.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - User Info Section

    private func userInfoSection(viewModel: ProfileViewModel) -> some View {
        Section {
            HStack(spacing: AppTheme.Spacing.md) {
                PersonaAvatar(persona: viewModel.selectedPersona, size: 64)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(viewModel.userName.isEmpty ? "User" : viewModel.userName)
                        .font(AppFonts.title3)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(viewModel.userEmail)
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(appState.engagementStreak) day streak")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(.vertical, AppTheme.Spacing.sm)
        }
    }

    // MARK: - Coaching Settings Section

    private var coachingSettingsSection: some View {
        Section("Coaching") {
            NavigationLink {
                if let viewModel {
                    PersonaSettingsView(viewModel: viewModel)
                }
            } label: {
                HStack {
                    Label {
                        Text("Coaching Persona")
                    } icon: {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(AppTheme.primary)
                    }

                    Spacer()

                    Text(viewModel?.selectedPersona.displayName ?? "")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            NavigationLink {
                if let viewModel {
                    VoiceSettingsView(viewModel: viewModel)
                }
            } label: {
                Label {
                    Text("Voice Settings")
                } icon: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section("Account") {
            NavigationLink {
                if let viewModel {
                    AccountSettingsView(viewModel: viewModel)
                }
            } label: {
                Label {
                    Text("Account Settings")
                } icon: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }

    // MARK: - Sign Out Section

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                showingSignOutConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .font(AppFonts.headline)
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    let appState = AppState()
    appState.currentUserName = "Alex Johnson"
    appState.currentUserEmail = "alex@company.com"
    appState.engagementStreak = 12

    return ProfileView()
        .environment(appState)
}
