import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - User Info
                Section {
                    if let name = appState.currentUserName {
                        HStack {
                            Text(String(name.prefix(1)))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(AppTheme.primary)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(name)
                                    .font(.headline)
                                if let email = appState.currentUserEmail {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // MARK: - Stats
                Section {
                    LabeledContent("Engagement Streak", value: "\(appState.engagementStreak) days")
                    NavigationLink {
                        CoachingStyleSettingsView(appState: appState)
                    } label: {
                        HStack {
                            Text("Preferred Style")
                            Spacer()
                            Text(appState.selectedCoachingStyle.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Your Progress")
                }

                // MARK: - Debug Options
                Section {
                    Toggle("Show Debug Diagnostics", isOn: Binding(
                        get: { appState.showDebugDiagnostics },
                        set: { appState.showDebugDiagnostics = $0 }
                    ))
                    
                    Button("Restart Onboarding") {
                        appState.hasCompletedOnboarding = false
                    }
                } header: {
                    Text("Developer Options")
                } footer: {
                    Text("Display coaching metadata (style, emotion, goal) in chat messages. Restart onboarding if you skipped it earlier.")
                }

                // MARK: - Account Actions
                Section {
                    Button(role: .destructive) {
                        appState.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

private struct CoachingStyleSettingsView: View {
    @Bindable var appState: AppState

    var body: some View {
        List {
            ForEach(CoachingStyle.allCases) { style in
                Button {
                    appState.selectedCoachingStyle = style
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.displayName)
                                .foregroundStyle(AppTheme.textPrimary)
                            if style == .auto {
                                Text("Lets the coach choose the best mode per turn")
                                    .font(AppFonts.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        Spacer()
                        if appState.selectedCoachingStyle == style {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Coach Mode")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileView()
        .environment(AppState())
}
