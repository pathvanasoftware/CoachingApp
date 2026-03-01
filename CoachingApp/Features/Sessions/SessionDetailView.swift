import SwiftUI

struct SessionDetailView: View {
    @Environment(AppState.self) private var appState
    let session: CoachingSession
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = true
    @State private var showFullTranscript = false

    private let chatService: ChatServiceProtocol

    init(
        session: CoachingSession,
        chatService: ChatServiceProtocol = MockChatService.shared
    ) {
        self.session = session
        self.chatService = chatService
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

                // Action items (placeholder for future integration)
                if !session.isActive {
                    actionItemsSection
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
                Text(session.persona.displayName)
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

    // MARK: - Action Items Section

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Label {
                Text("Action Items")
                    .font(AppFonts.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            } icon: {
                Image(systemName: "checklist")
                    .foregroundStyle(AppTheme.primary)
            }

            // Placeholder action items derived from the session
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                actionItemRow(
                    title: "Review and refine your approach",
                    isCompleted: false
                )
                actionItemRow(
                    title: "Schedule follow-up discussion",
                    isCompleted: false
                )
                actionItemRow(
                    title: "Reflect on key takeaways",
                    isCompleted: true
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }

    private func actionItemRow(title: String, isCompleted: Bool) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isCompleted ? AppTheme.success : AppTheme.textTertiary)
                .font(.system(size: 18))

            Text(title)
                .font(AppFonts.body)
                .foregroundStyle(isCompleted ? AppTheme.textTertiary : AppTheme.textPrimary)
                .strikethrough(isCompleted)
        }
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
        do {
            messages = try await chatService.getMessages(sessionId: session.id)
        } catch {
            messages = []
        }
        isLoading = false
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
                durationSeconds: 1845,
                messageCount: 12
            )
        )
    }
    .environment(AppState())
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
}
