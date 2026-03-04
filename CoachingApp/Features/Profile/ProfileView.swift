import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(ServiceContainer.self) private var services

    @State private var stats = ProfileConversationStats.empty
    @State private var isLoadingStats = false
    @State private var statusMessage: String?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                userInfoSection
                progressSection
                conversationStatsSection
                dataPrivacySection

#if DEBUG
                developerOptionsSection
#endif

                accountActionsSection
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .task {
                await loadConversationStats()
            }
        }
    }

    // MARK: - Sections

    private var userInfoSection: some View {
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
    }

    private var progressSection: some View {
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
    }

    private var conversationStatsSection: some View {
        Section {
            if isLoadingStats {
                HStack {
                    ProgressView()
                    Text("Loading conversation stats...")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else {
                LabeledContent("Total Sessions", value: "\(stats.totalSessions)")
                LabeledContent("Active Sessions", value: "\(stats.activeSessions)")
                LabeledContent("Avg Session Length", value: stats.averageDurationLabel)
                LabeledContent("Last Session", value: stats.lastSessionLabel)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        } header: {
            Text("Conversation Stats")
        }
    }

    private var dataPrivacySection: some View {
        Section {
            Button {
                Task { await exportConversations() }
            } label: {
                HStack {
                    Text("Export Conversations")
                    Spacer()
                    if isExporting {
                        ProgressView()
                    }
                }
            }
            .disabled(isExporting)

            Button(role: .destructive) {
                Task { await clearConversationData() }
            } label: {
                Text("Clear Conversation History")
            }
        } header: {
            Text("Data & Privacy")
        } footer: {
            Text("Export saves a Markdown transcript. Clear removes local conversation history in this app environment.")
        }
    }

#if DEBUG
    private var developerOptionsSection: some View {
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
    }
#endif

    private var accountActionsSection: some View {
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

    // MARK: - Actions

    private func loadConversationStats() async {
        guard let userId = appState.currentUserId else { return }
        isLoadingStats = true
        defer { isLoadingStats = false }

        do {
            let sessions = try await services.chatService.getSessionHistory(userId: userId)
            stats = ProfileConversationStats(sessions: sessions)
            if sessions.isEmpty {
                statusMessage = "No sessions yet. Start your first coaching conversation from Home or Sessions."
            } else {
                statusMessage = nil
            }
        } catch {
            statusMessage = "Could not load stats right now."
        }
    }

    private func exportConversations() async {
        guard let userId = appState.currentUserId else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let sessions = try await services.chatService.getSessionHistory(userId: userId)
            guard !sessions.isEmpty else {
                statusMessage = "No conversations to export yet."
                return
            }

            var messagesBySession: [String: [ChatMessage]] = [:]
            for session in sessions {
                messagesBySession[session.id] = try await services.chatService.getMessages(sessionId: session.id)
            }

            let markdown = buildExportMarkdown(sessions: sessions, messagesBySession: messagesBySession)
            let fileName = "coaching_export_\(Date().timeIntervalSince1970).md"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try markdown.write(to: url, atomically: true, encoding: .utf8)

            exportURL = url
            showShareSheet = true
            statusMessage = "Export prepared."
        } catch {
            statusMessage = "Failed to export conversations."
        }
    }

    private func clearConversationData() async {
        guard let userId = appState.currentUserId else { return }

        if let mockService = services.chatService as? MockChatService {
            mockService.clearUserData(userId: userId)
            appState.activeSession = nil
            appState.activeSessionMessages = []
            statusMessage = "Conversation history cleared."
            await loadConversationStats()
        } else {
            statusMessage = "Remote history deletion is not available yet in production."
        }
    }

    private func buildExportMarkdown(
        sessions: [CoachingSession],
        messagesBySession: [String: [ChatMessage]]
    ) -> String {
        var lines: [String] = []
        lines.append("# Coaching Conversation Export")
        lines.append("")
        lines.append("Exported: \(DateFormatter.profileExport.string(from: Date()))")
        lines.append("Total sessions: \(sessions.count)")
        lines.append("")

        for session in sessions {
            lines.append("## Session \(session.id)")
            lines.append("- Type: \(session.sessionType.displayName)")
            lines.append("- Started: \(DateFormatter.profileExport.string(from: session.startedAt))")
            lines.append("- Duration: \(session.formattedDuration)")
            lines.append("- Messages: \(session.messageCount)")
            lines.append("")

            let messages = messagesBySession[session.id] ?? []
            for message in messages {
                let role = message.isFromCoach ? "Coach" : "You"
                lines.append("**\(role):** \(message.content)")
                lines.append("")
            }

            lines.append("---")
            lines.append("")
        }

        return lines.joined(separator: "\n")
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
                            Text("Selected")
                                .font(AppFonts.caption)
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderless)
                .listRowBackground(
                    appState.selectedCoachingStyle == style
                        ? AppTheme.primary.opacity(0.08)
                        : Color.clear
                )
            }
        }
        .navigationTitle("Coach Mode")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileConversationStats {
    let totalSessions: Int
    let activeSessions: Int
    let averageDurationSeconds: Int
    let lastSessionDate: Date?

    static let empty = ProfileConversationStats(
        totalSessions: 0,
        activeSessions: 0,
        averageDurationSeconds: 0,
        lastSessionDate: nil
    )

    init(totalSessions: Int, activeSessions: Int, averageDurationSeconds: Int, lastSessionDate: Date?) {
        self.totalSessions = totalSessions
        self.activeSessions = activeSessions
        self.averageDurationSeconds = averageDurationSeconds
        self.lastSessionDate = lastSessionDate
    }

    init(sessions: [CoachingSession]) {
        totalSessions = sessions.count
        activeSessions = sessions.filter(\.isActive).count
        let completedDurations = sessions.compactMap(\.durationSeconds)
        averageDurationSeconds = completedDurations.isEmpty
            ? 0
            : completedDurations.reduce(0, +) / completedDurations.count
        lastSessionDate = sessions.map(\.startedAt).max()
    }

    var averageDurationLabel: String {
        guard averageDurationSeconds > 0 else { return "--" }
        let minutes = averageDurationSeconds / 60
        return "\(minutes)m"
    }

    var lastSessionLabel: String {
        guard let lastSessionDate else { return "--" }
        return lastSessionDate.relativeDisplay
    }
}

private extension DateFormatter {
    static let profileExport: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    ProfileView()
        .environment(AppState())
        .environment(ServiceContainer())
}
