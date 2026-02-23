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
                    LabeledContent("Preferred Style", value: appState.selectedCoachingStyle.displayName)
                } header: {
                    Text("Your Progress")
                }

                // MARK: - API Configuration
                Section {
                    Picker("API Environment", selection: Binding(
                        get: { appState.apiEnvironment },
                        set: { appState.switchAPIEnvironment($0) }
                    )) {
                        ForEach(APIEnvironment.allCases, id: \.self) { env in
                            Text(env.description).tag(env)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    LabeledContent("Current URL", value: appState.apiEnvironment.baseURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("API Configuration")
                } footer: {
                    Text("Switch between local development and production servers.")
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

#Preview {
    ProfileView()
        .environment(AppState())
}
