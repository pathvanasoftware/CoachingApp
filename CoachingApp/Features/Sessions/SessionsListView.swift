import SwiftUI

struct SessionsListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SessionsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.sessions.isEmpty {
                    LoadingView(message: "Loading sessions...")
                } else if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    sessionsList
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        newSessionDestination
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }
            .task {
                await viewModel.loadSessions(
                    userId: appState.currentUserId ?? "mock-user-id"
                )
            }
            .refreshable {
                await viewModel.loadSessions(
                    userId: appState.currentUserId ?? "mock-user-id"
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right.fill",
            title: "No Sessions Yet",
            message: "Start a coaching session to see your history here.",
            buttonTitle: "Start Session"
        ) {
            // Button action handled by navigation
        }
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        List {
            // Active sessions section
            if !viewModel.activeSessions.isEmpty {
                Section {
                    ForEach(viewModel.activeSessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRowView(session: session)
                        }
                    }
                } header: {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Circle()
                            .fill(AppTheme.success)
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .font(AppFonts.caption)
                            .textCase(.uppercase)
                    }
                }
            }

            // Grouped completed sessions
            ForEach(viewModel.groupedSessions, id: \.key) { group in
                Section {
                    ForEach(group.sessions.filter { !$0.isActive }) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRowView(session: session)
                        }
                    }
                    .onDelete { offsets in
                        let completedInGroup = group.sessions.filter { !$0.isActive }
                        viewModel.deleteSession(at: offsets, from: completedInGroup)
                    }
                } header: {
                    Text(group.key)
                        .font(AppFonts.caption)
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - New Session Destination

    private var newSessionDestination: some View {
        ChatView(
            sessionType: .freeform,
            persona: appState.selectedPersona
        )
    }
}

// MARK: - Session Row View

private struct SessionRowView: View {
    let session: CoachingSession

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Persona icon
            PersonaAvatar(persona: session.persona, size: 44)

            // Session details
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Label {
                        Text(session.sessionType.displayName)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                    } icon: {
                        Image(systemName: session.sessionType.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(session.persona.accentColor)
                    }

                    Spacer()

                    if session.isActive {
                        activeBadge
                    }
                }

                // Date and stats
                HStack(spacing: AppTheme.Spacing.md) {
                    Text(session.startedAt.relativeDisplay)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    if session.messageCount > 0 {
                        Label("\(session.messageCount)", systemImage: "message.fill")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }

                    if !session.isActive {
                        Text(session.formattedDuration)
                            .font(AppFonts.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }

                // Summary preview
                if let summary = session.summary, !summary.isEmpty {
                    Text(summary)
                        .font(AppFonts.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                        .padding(.top, AppTheme.Spacing.xxs)
                }
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private var activeBadge: some View {
        Text("Active")
            .font(AppFonts.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xxs)
            .background(AppTheme.success)
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    SessionsListView()
        .environment(AppState())
}
