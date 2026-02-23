import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()
    @State private var isShowingChat = false
    @State private var hasHandledLaunchArgs = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    if let error = viewModel.loadErrorMessage {
                        errorBanner(error)
                    }

                    // Greeting Header
                    greetingSection

                    // Daily Check-In Card
                    DailyCheckInCard(
                        persona: appState.selectedPersona,
                        onStartSession: {
                            isShowingChat = true
                        }
                    )

                    // Streak Display
                    if appState.engagementStreak > 0 {
                        StreakView(streak: appState.engagementStreak)
                    }

                    // Today's Action Items
                    actionItemsSection

                    // Recent Sessions
                    recentSessionsSection
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.background)
            .navigationTitle("Home")
            .task {
                await viewModel.loadData()
            }
            .onAppear {
                guard !hasHandledLaunchArgs else { return }
                hasHandledLaunchArgs = true
                let args = ProcessInfo.processInfo.arguments
                if args.contains("--open-chat") {
                    isShowingChat = true
                }
            }
            .refreshable {
                await viewModel.loadData()
            }
            .overlay {
                if viewModel.isLoading && viewModel.actionItems.isEmpty {
                    LoadingView(message: "Loading your dashboard...")
                        .allowsHitTesting(false)
                }
            }
        }
        .sheet(isPresented: $isShowingChat) {
            ChatScreen()
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warning)
            Text(message)
                .font(AppFonts.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Button("Retry") {
                Task { await viewModel.loadData() }
            }
            .font(AppFonts.caption)
            .foregroundStyle(AppTheme.primary)
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
    }

    // MARK: - Greeting Section

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text("\(viewModel.greeting), \(appState.currentUserName ?? "there")")
                .font(AppFonts.title)
                .foregroundStyle(AppTheme.textPrimary)

            Text(greetingSubtitle)
                .font(AppFonts.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var greetingSubtitle: String {
        let pendingCount = viewModel.todayActionItems.count
        let overdueCount = viewModel.overdueActionItems.count

        if overdueCount > 0 {
            return "You have \(overdueCount) overdue item\(overdueCount == 1 ? "" : "s") to address."
        } else if pendingCount > 0 {
            return "You have \(pendingCount) action item\(pendingCount == 1 ? "" : "s") for today."
        } else {
            return "You're all caught up. Ready for a session?"
        }
    }

    // MARK: - Action Items Section

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("Today's Actions")
                    .font(AppFonts.title3)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                if viewModel.completedTodayCount > 0 {
                    Text("\(viewModel.completedTodayCount) done")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.success)
                }
            }

            ActionItemsList(
                actionItems: viewModel.todayActionItems + viewModel.overdueActionItems,
                onToggle: { item in viewModel.toggleActionItem(item) }
            )
        }
    }

    // MARK: - Recent Sessions Section

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Recent Sessions")
                .font(AppFonts.title3)
                .foregroundStyle(AppTheme.textPrimary)

            if viewModel.recentSessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Start Your First Session")
                        .font(AppFonts.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Tap the check-in card above to begin! 💬")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AppTheme.Spacing.lg)
            } else {
                ForEach(viewModel.recentSessions.prefix(3)) { session in
                    recentSessionRow(session)
                }
            }
        }
    }

    private func recentSessionRow(_ session: CoachingSession) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            PersonaAvatar(persona: session.persona, size: 40)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text(session.sessionType.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Text(session.startedAt.relativeDisplay)
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }

                if let summary = session.summary {
                    Text(summary)
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: AppTheme.Spacing.sm) {
                    Label(session.formattedDuration, systemImage: "clock")
                    Label("\(session.messageCount) messages", systemImage: "bubble.left")
                }
                .font(AppFonts.caption)
                .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .cardStyle()
    }
}

#Preview {
    let appState = AppState()
    appState.currentUserName = "Alex"
    appState.engagementStreak = 7
    appState.isAuthenticated = true

    return HomeView()
        .environment(appState)
}
