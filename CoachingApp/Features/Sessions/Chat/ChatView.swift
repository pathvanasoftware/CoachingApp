import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel: ChatViewModel
    @State private var hasInitialized = false

    // Configuration for starting a new session
    private let sessionType: SessionType?
    private let persona: CoachingPersonaType?

    // Configuration for resuming an existing session
    private let existingSession: CoachingSession?

    // MARK: - Initializers

    /// Start a new session with the given type and persona.
    init(
        sessionType: SessionType,
        persona: CoachingPersonaType,
        chatService: ChatServiceProtocol? = nil,
        streamingService: StreamingServiceProtocol? = nil
    ) {
        self.sessionType = sessionType
        self.persona = persona
        self.existingSession = nil

        let shared = MockChatService.shared
        self._viewModel = State(
            initialValue: ChatViewModel(
                chatService: chatService ?? shared,
                streamingService: streamingService ?? shared
            )
        )
    }

    /// Resume an existing session.
    init(
        session: CoachingSession,
        chatService: ChatServiceProtocol? = nil,
        streamingService: StreamingServiceProtocol? = nil
    ) {
        self.sessionType = nil
        self.persona = nil
        self.existingSession = session

        let shared = MockChatService.shared
        self._viewModel = State(
            initialValue: ChatViewModel(
                chatService: chatService ?? shared,
                streamingService: streamingService ?? shared
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            messagesScrollView

            // Typing indicator (only when there is no streaming coach bubble yet)
            if showTypingIndicator {
                TypingIndicatorView(
                    persona: currentPersona
                )
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Error banner
            if let errorMessage = viewModel.errorMessage {
                errorBanner(errorMessage)
            }

            // Input bar
            MessageInputBar(
                text: $viewModel.currentInput,
                isEnabled: !viewModel.isStreaming && viewModel.currentSession != nil,
                onSend: {
                    Task { await viewModel.sendMessage() }
                },
                onVoiceTap: {
                    viewModel.isVoiceMode.toggle()
                }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(currentPersona.displayName)
                        .font(AppFonts.headline)
                    if viewModel.currentSession?.isActive == true {
                        SessionTimerView(elapsedSeconds: viewModel.elapsedSeconds)
                    }
                    Text(connectionModeLabel)
                        .font(AppFonts.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(connectionModeColor.opacity(0.18))
                        .foregroundStyle(connectionModeColor)
                        .clipShape(Capsule())
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if viewModel.isVoiceMode {
                        Button {
                            viewModel.isVoiceMode = false
                        } label: {
                            Label("Switch to Text", systemImage: "keyboard")
                        }
                    } else {
                        Button {
                            viewModel.isVoiceMode = true
                        } label: {
                            Label("Switch to Voice", systemImage: "mic.fill")
                        }
                    }

                    if viewModel.currentSession?.isActive == true {
                        Divider()
                        Button(role: .destructive) {
                            Task { await viewModel.endSession() }
                        } label: {
                            Label("End Session", systemImage: "stop.circle.fill")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .task {
            // Wire real services from the environment before starting the session
            viewModel.chatService = services.chatService
            viewModel.streamingService = services.streamingService
            guard !hasInitialized else { return }
            hasInitialized = true
            await initializeSession()
        }
        .onDisappear {
            appState.activeSession = viewModel.currentSession
            appState.activeSessionMessages = viewModel.messages
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isStreaming)
    }

    private var connectionModeLabel: String {
        if appState.useMockServices { return "MOCK" }
        if appState.apiEnvironment == .localhost { return "LOCALHOST" }
        return "LIVE"
    }

    private var showTypingIndicator: Bool {
        guard viewModel.isStreaming else { return false }
        if let last = viewModel.messages.last,
           last.isFromCoach,
           last.isStreaming {
            return false
        }
        return true
    }

    private var connectionModeColor: Color {
        if appState.useMockServices { return .orange }
        if appState.apiEnvironment == .localhost { return .red }
        return .green
    }

    // MARK: - Subviews

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            persona: currentPersona
                        )
                        .id(message.id)
                    }

                    // Quick reply chips — shown below the last coach message,
                    // hidden while the model is still streaming.
                    // Negative horizontal padding breaks out of the LazyVStack's
                    // padding so the scroll view can reach the screen edges.
                    if !viewModel.isStreaming,
                       !viewModel.currentQuickReplies.isEmpty,
                       viewModel.messages.last?.isFromCoach == true {
                        QuickReplyView(
                            suggestions: viewModel.currentQuickReplies,
                            onSelect: { viewModel.handleQuickReply($0) },
                            onRequestHumanCoach: { viewModel.requestHumanCoach() }
                        )
                        .id("quickReplies")
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.content) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.currentQuickReplies.count) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warning)

            Text(message)
                .font(AppFonts.footnote)
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.warning.opacity(0.1))
    }

    // MARK: - Helpers

    private var currentPersona: CoachingPersonaType {
        viewModel.currentSession?.persona ?? persona ?? appState.selectedPersona
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    @MainActor
    private func initializeSession() async {
        if viewModel.currentSession != nil { return }

        if let existingSession {
            await viewModel.loadExistingSession(existingSession)
        } else if let restored = appState.activeSession, restored.isActive {
            viewModel.currentSession = restored
            viewModel.messages = appState.activeSessionMessages
            if restored.isActive {
                viewModel.startTimer()
            }
        } else if let sessionType, let persona {
            await viewModel.startSession(
                type: sessionType,
                persona: persona,
                userId: appState.currentUserId ?? "mock-user-id"
            )
        }
    }
}

// MARK: - Preview

#Preview("New Session") {
    NavigationStack {
        ChatView(
            sessionType: .checkIn,
            persona: .directChallenger
        )
    }
    .environment(AppState())
    .environment(ServiceContainer())
}

#Preview("Supportive Strategist") {
    NavigationStack {
        ChatView(
            sessionType: .deepDive,
            persona: .supportiveStrategist
        )
    }
    .environment(AppState())
    .environment(ServiceContainer())
}
