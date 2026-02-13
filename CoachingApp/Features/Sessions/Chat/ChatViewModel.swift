import Foundation

@Observable
final class ChatViewModel {

    // MARK: - Published State

    var messages: [ChatMessage] = []
    var currentInput: String = ""
    var isLoading: Bool = false
    var isStreaming: Bool = false
    var currentSession: CoachingSession?
    var elapsedSeconds: Int = 0
    var errorMessage: String?
    var isVoiceMode: Bool = false

    // MARK: - Dependencies

    private let chatService: ChatServiceProtocol
    private let streamingService: StreamingServiceProtocol

    // MARK: - Private State

    private var timerTask: Task<Void, Never>?
    private var streamingTask: Task<Void, Never>?

    // MARK: - Init

    init(
        chatService: ChatServiceProtocol = MockChatService(),
        streamingService: StreamingServiceProtocol = MockChatService()
    ) {
        self.chatService = chatService
        self.streamingService = streamingService
    }

    // MARK: - Session Lifecycle

    @MainActor
    func startSession(
        type: SessionType,
        persona: CoachingPersonaType,
        userId: String = "mock-user-id",
        inputMode: InputMode = .text
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let session = try await chatService.startSession(
                userId: userId,
                persona: persona,
                sessionType: type,
                inputMode: inputMode
            )
            currentSession = session
            messages = []
            startTimer()

            // Stream the initial greeting from the coach
            await streamInitialGreeting(for: session)
        } catch {
            errorMessage = "Failed to start session: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    func loadExistingSession(_ session: CoachingSession) async {
        isLoading = true
        errorMessage = nil
        currentSession = session

        do {
            messages = try await chatService.getMessages(sessionId: session.id)

            if session.isActive {
                // Calculate elapsed time from session start
                elapsedSeconds = Int(Date().timeIntervalSince(session.startedAt))
                startTimer()
            } else {
                elapsedSeconds = session.durationSeconds ?? 0
            }
        } catch {
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
        }

        isLoading = false
    }

    @MainActor
    func endSession() async {
        guard let session = currentSession else { return }
        stopTimer()

        do {
            let endedSession = try await chatService.endSession(sessionId: session.id)
            currentSession = endedSession
        } catch {
            errorMessage = "Failed to end session: \(error.localizedDescription)"
        }
    }

    // MARK: - Messaging

    @MainActor
    func sendMessage() async {
        let content = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, let session = currentSession else { return }
        guard !isStreaming else { return }

        // Clear input immediately
        currentInput = ""
        errorMessage = nil

        // Add user message to the local list
        let userMessage = ChatMessage(
            sessionId: session.id,
            role: .user,
            content: content
        )
        messages.append(userMessage)

        // Stream the assistant response
        await streamAssistantResponse(content: content, for: session)
    }

    @MainActor
    func cancelStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false

        // Finalize partial message
        if let lastIndex = messages.indices.last,
           messages[lastIndex].role == .assistant,
           messages[lastIndex].isStreaming {
            messages[lastIndex].isStreaming = false
            if messages[lastIndex].content.isEmpty {
                messages.removeLast()
            }
        }
    }

    // MARK: - Timer

    func startTimer() {
        stopTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self?.elapsedSeconds += 1
                }
            }
        }
    }

    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Private Helpers

    @MainActor
    private func streamInitialGreeting(for session: CoachingSession) async {
        isStreaming = true

        // Create a placeholder assistant message
        let assistantMessage = ChatMessage(
            sessionId: session.id,
            role: .assistant,
            content: "",
            isStreaming: true
        )
        messages.append(assistantMessage)

        let stream = streamingService.streamResponse(
            sessionId: session.id,
            message: "",
            persona: session.persona
        )

        do {
            for try await token in stream {
                guard let lastIndex = messages.indices.last else { break }
                messages[lastIndex].content += token
            }
        } catch {
            // Streaming interrupted -- keep whatever content we have
        }

        // Finalize the message
        if let lastIndex = messages.indices.last {
            messages[lastIndex].isStreaming = false
        }

        isStreaming = false
    }

    @MainActor
    private func streamAssistantResponse(content: String, for session: CoachingSession) async {
        isStreaming = true

        // Create a placeholder assistant message
        let assistantMessage = ChatMessage(
            sessionId: session.id,
            role: .assistant,
            content: "",
            isStreaming: true
        )
        messages.append(assistantMessage)

        let stream = streamingService.streamResponse(
            sessionId: session.id,
            message: content,
            persona: session.persona
        )

        streamingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    guard let lastIndex = self.messages.indices.last else { break }
                    self.messages[lastIndex].content += token
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = "Response was interrupted. Please try again."
                }
            }

            // Finalize the message
            if let lastIndex = self.messages.indices.last {
                self.messages[lastIndex].isStreaming = false
            }

            self.isStreaming = false
            self.streamingTask = nil
        }
    }
}
