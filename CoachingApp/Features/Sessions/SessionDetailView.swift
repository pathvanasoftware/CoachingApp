import SwiftUI

struct SessionDetailView: View {
    @Environment(ServiceContainer.self) private var services
    let session: CoachingSession
    @State private var messages: [ChatMessage] = []
    @State private var linkedGoals: [Goal] = []
    @State private var isLoading = true
    @State private var showFullTranscript = false

    private let historyStorage = ChatHistoryStorage.shared

    init(session: CoachingSession) {
        self.session = session
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Session header
                sessionHeader

                // Summary section (for completed sessions)
                if let summary = session.summary, !summary.isEmpty {
                    summarySection(summary)
                }

                if let structuredSummary = session.sessionSummary {
                    if !structuredSummary.keyInsights.isEmpty {
                        insightSection(structuredSummary.keyInsights)
                    }

                    if !structuredSummary.actionItems.isEmpty {
                        actionItemsSection(structuredSummary.actionItems)
                    }

                    if !structuredSummary.recommendedNextSteps.isEmpty {
                        nextStepsSection(structuredSummary.recommendedNextSteps)
                    }
                }

                if !session.goalIds.isEmpty {
                    linkedGoalsSection
                }

                // Transcript
                transcriptSection

                // Continue session button
                if session.isActive {
                    continueSessionButton
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessages()
        }
    }

    // MARK: - Session Header

    private var sessionHeader: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            PersonaAvatar(persona: session.persona, size: 64)

            VStack(spacing: AppTheme.Spacing.xs) {
                Text("Coach")
                    .font(AppFonts.title3)
                    .foregroundStyle(AppTheme.textPrimary)

                Label {
                    Text(session.sessionType.displayName)
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } icon: {
                    Image(systemName: session.sessionType.icon)
                        .foregroundStyle(session.persona.accentColor)
                }
            }

            // Session metadata
            HStack(spacing: AppTheme.Spacing.lg) {
                metadataItem(
                    icon: "calendar",
                    label: session.startedAt.relativeDisplay
                )

                metadataItem(
                    icon: "clock.fill",
                    label: session.formattedDuration
                )

                metadataItem(
                    icon: "message.fill",
                    label: "\(session.messageCount) messages"
                )
            }
            .padding(.top, AppTheme.Spacing.xs)

            if !session.goalIds.isEmpty {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "target")
                        .foregroundStyle(AppTheme.primary)
                    Text("\(session.goalIds.count) linked goal\(session.goalIds.count == 1 ? "" : "s")")
                        .font(AppFonts.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            if session.isActive {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Circle()
                        .fill(AppTheme.success)
                        .frame(width: 8, height: 8)
                    Text("Session in progress")
                        .font(AppFonts.footnote)
                        .foregroundStyle(AppTheme.success)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
    }

    private func metadataItem(icon: String, label: String) -> some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textTertiary)

            Text(label)
                .font(AppFonts.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Summary Section

    private func summarySection(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Label {
                Text("Session Summary")
                    .font(AppFonts.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            } icon: {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(AppTheme.primary)
            }

            Text(summary)
                .font(AppFonts.body)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }

    // MARK: - Structured Summary Sections

    private func insightSection(_ insights: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Label {
                Text("Key Insights")
                    .font(AppFonts.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            } icon: {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(insights, id: \.self) { insight in
                    bulletRow(icon: "circle.fill", text: insight)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }

    private func actionItemsSection(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Label {
                Text("Action Items")
                    .font(AppFonts.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            } icon: {
                Image(systemName: "checklist")
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(items, id: \.self) { item in
                    bulletRow(icon: "checkmark.circle.fill", text: item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }

    private func nextStepsSection(_ steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Label {
                Text("Recommended Next Steps")
                    .font(AppFonts.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            } icon: {
                Image(systemName: "arrow.forward.circle.fill")
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(steps, id: \.self) { step in
                    bulletRow(icon: "arrow.right.circle.fill", text: step)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }

    private func bulletRow(icon: String, text: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.primary)
                .font(.system(size: 14))

            Text(text)
                .font(AppFonts.body)
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()
        }
    }

    // MARK: - Linked Goals

    private var linkedGoalsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Label {
                Text("Linked Goals")
                    .font(AppFonts.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            } icon: {
                Image(systemName: "target")
                    .foregroundStyle(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(session.goalIds, id: \.self) { goalId in
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(AppTheme.primary)

                        Text(linkedGoalTitle(for: goalId))
                            .font(AppFonts.body)
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)

                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }

    private func linkedGoalTitle(for goalId: String) -> String {
        linkedGoals.first(where: { $0.id == goalId })?.title ?? "Goal \(goalId.prefix(8))"
    }

    // MARK: - Transcript Section

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Label {
                    Text("Transcript")
                        .font(AppFonts.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                } icon: {
                    Image(systemName: "text.quote")
                        .foregroundStyle(AppTheme.primary)
                }

                Spacer()

                if messages.count > 4 {
                    Button {
                        showFullTranscript.toggle()
                    } label: {
                        Text(showFullTranscript ? "Show Less" : "Show All")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(AppTheme.Spacing.lg)
                    Spacer()
                }
            } else if messages.isEmpty {
                Text("No messages in this session.")
                    .font(AppFonts.body)
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.vertical, AppTheme.Spacing.md)
            } else {
                let displayMessages = showFullTranscript ? messages : Array(messages.prefix(4))

                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(displayMessages) { message in
                        transcriptMessageRow(message)
                    }
                }

                if !showFullTranscript && messages.count > 4 {
                    Text("\(messages.count - 4) more messages...")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppTheme.Spacing.xs)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }

    private func transcriptMessageRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            if message.isFromCoach {
                PersonaAvatar(persona: session.persona, size: 24)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(AppTheme.userBubble)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                HStack {
                    Text(message.isFromCoach ? "Coach" : "You")
                        .font(AppFonts.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.textSecondary)

                    Spacer()

                    Text(message.timestamp.timeDisplay)
                        .font(AppFonts.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }

                Text(message.content)
                    .font(AppFonts.footnote)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppTheme.Spacing.sm)
        .background(
            message.isFromCoach
                ? AppTheme.coachBubble.opacity(0.5)
                : AppTheme.userBubble.opacity(0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
    }

    // MARK: - Continue Session Button

    private var continueSessionButton: some View {
        NavigationLink {
            ChatView(session: session)
        } label: {
            Text("Continue Session")
                .primaryButtonStyle()
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - Data Loading

    @MainActor
    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let goalFetch = services.goalService.fetchGoals(userId: session.userId)
            if let (_, savedMessages) = try await historyStorage.loadSession(id: session.id), !savedMessages.isEmpty {
                messages = savedMessages
            } else {
                messages = try await services.chatService.getMessages(sessionId: session.id)
            }

            let goals = try await goalFetch
            linkedGoals = goals.filter { session.goalIds.contains($0.id) }
        } catch {
            messages = []
            linkedGoals = []
        }
    }
}

// MARK: - Preview

#Preview("Completed Session") {
    NavigationStack {
        SessionDetailView(
            session: CoachingSession(
                userId: "mock-user-id",
                persona: .directChallenger,
                sessionType: .checkIn,
                startedAt: Date().addingTimeInterval(-3600),
                endedAt: Date(),
                summary: "Discussed upcoming board presentation. Identified key areas of preparation needed and practiced handling tough questions from the board chair.",
                sessionSummary: CoachingSessionSummary(
                    summary: "Clarified the board narrative and tightened the opening story.",
                    keyInsights: ["The story needed a stronger business outcome frame."],
                    actionItems: ["Rewrite the opening in three sentences."],
                    progressMade: "You moved from broad themes to a sharper executive narrative.",
                    recommendedNextSteps: ["Practice the opening out loud twice before the meeting."]
                ),
                durationSeconds: 1845,
                messageCount: 12,
                goalIds: ["goal-123"]
            )
        )
    }
    .environment(AppState())
    .environment(ServiceContainer())
}

#Preview("Active Session") {
    NavigationStack {
        SessionDetailView(
            session: CoachingSession(
                userId: "mock-user-id",
                persona: .supportiveStrategist,
                sessionType: .freeform,
                messageCount: 4
            )
        )
    }
    .environment(AppState())
    .environment(ServiceContainer())
}
