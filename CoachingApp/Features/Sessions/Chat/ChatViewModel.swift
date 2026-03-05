import Foundation
#if canImport(UIKit)
import UIKit
#endif

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
    var lastSavedAt: Date?
    var sessionSummary: CoachingSessionSummary?
    var isGeneratingSummary: Bool = false

    // MARK: - Handoff & Crisis State

    var showHandoffOptions: Bool = false
    var showCrisisResources: Bool = false
    var hasSubscription: Bool = false
    var showQuickRepliesFor: String?
    var selectedCoachingStyle: CoachingStyle = .auto

    // MARK: - Dependencies

    var chatService: ChatServiceProtocol
    var streamingService: StreamingServiceProtocol
    private let historyStorage = ChatHistoryStorage.shared

    // MARK: - Private State

    private var timerTask: Task<Void, Never>?
    private var streamingTask: Task<Void, Never>?
    private var voiceInputManager: VoiceInputManager?
    private var pendingHumanCoachRequest: Bool = false
    private var pendingDiagnostics: CoachingDiagnostics?

    // Dynamic quick reply suggestions, updated after each assistant message
    var currentQuickReplies: [QuickReply] = []

    // MARK: - Init

    init(
        chatService: ChatServiceProtocol = MockChatService.shared,
        streamingService: StreamingServiceProtocol = MockChatService.shared
    ) {
        self.chatService = chatService
        self.streamingService = streamingService
    }

    deinit {
        timerTask?.cancel()
        streamingTask?.cancel()
        voiceInputManager = nil
    }

    // MARK: - Session Lifecycle

    @MainActor
    func startSession(
        type: SessionType,
        persona: CoachingPersonaType,
        userId: String = "test-user-001",
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

            // Render initial greeting instantly from local templates.
            appendLocalOpening(for: session)
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
            if let (_, savedMessages) = try await historyStorage.loadSession(id: session.id), !savedMessages.isEmpty {
                messages = savedMessages
            } else {
                messages = try await chatService.getMessages(sessionId: session.id)
            }

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
            // Save final session state
            saveCurrentSession()
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

        // Add user message to the local list (sending status)
        let userMessage = ChatMessage(
            sessionId: session.id,
            role: .user,
            content: content,
            status: .sending
        )
        messages.append(userMessage)

        // Crisis signal should trigger immediately and visibly.
        if containsCrisisSignal(in: content) {
            showCrisisResources = true
        }

        // Build diagnostics for the upcoming assistant turn
        pendingDiagnostics = buildDiagnostics(for: content)

        // Stream the assistant response
        await streamAssistantResponse(content: content, requestId: userMessage.id, for: session)

        // Haptic feedback on send
        await MainActor.run {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }

    func retryMessage(_ messageId: String) async {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              messages[index].role == .user,
              messages[index].status == .failed else { return }

        let content = messages[index].content
        guard let session = currentSession else { return }

        // Reset status to sending
        messages[index].status = .sending
        errorMessage = nil

        // Retry the assistant response
        await streamAssistantResponse(content: content, requestId: messageId, for: session)

        // Haptic feedback
        await MainActor.run {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
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
                    guard let self = self else { return }
                    self.elapsedSeconds += 1
                }
                guard !Task.isCancelled else { break }
            }
        }
    }

    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Private Helpers

    @MainActor
    private func appendLocalOpening(for session: CoachingSession) {
        let candidates = openingCandidates(for: session)
        let opening = candidates[stableIndex(seed: session.id, count: candidates.count)]

        let assistantMessage = ChatMessage(
            sessionId: session.id,
            role: .assistant,
            content: opening,
            diagnostics: CoachingDiagnostics(
                styleUsed: selectedCoachingStyle.displayName,
                emotionDetected: "neutral",
                goalLink: "professional_growth",
                goalAnchor: nil,
                goalHierarchySummary: nil,
                progressiveSkillSummary: nil,
                outcomePredictionSummary: nil,
                riskLevel: nil,
                recommendedStyleShift: nil
            )
        )

        messages.append(assistantMessage)
        currentQuickReplies = openingQuickReplies(for: session.sessionType)
        saveCurrentSession()
    }

    private func stableIndex(seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let checksum = seed.utf8.reduce(0) { partial, byte in
            (partial * 31 + Int(byte)) % 1_000_000
        }
        return checksum % count
    }

    private func openingCandidates(for session: CoachingSession) -> [String] {
        switch selectedCoachingStyle {
        case .directive:
            switch session.sessionType {
            case .checkIn:
                return ["Let's get straight to it: what is the single highest-stakes issue today?", "What is the one conversation you're avoiding that is costing you the most right now?"]
            case .deepDive:
                return ["Name the toughest challenge right now and the outcome you need.", "What problem do you want to dissect first so we can leave with a concrete move?"]
            case .freeform:
                return ["What's the one thing you want to leave this session with?", "If we solve one issue in this session, which one matters most?"]
            case .goalReview:
                return ["Which goal is currently off track, and by how much?", "What changed since your last goal check-in that we need to address now?"]
            }
        case .facilitative:
            switch session.sessionType {
            case .checkIn:
                return ["What's most alive for you today, and why does it matter now?", "What would make this check-in genuinely useful for you?"]
            case .deepDive:
                return ["What challenge feels worth unpacking deeply right now?", "Where would you like to spend time exploring before deciding on action?"]
            case .freeform:
                return ["Where would you like to begin today?", "What feels most important to explore first?"]
            case .goalReview:
                return ["Which goal would you like to review first, and what has shifted?", "As you look at your goals, where do you feel momentum and where do you feel friction?"]
            }
        case .supportive:
            switch session.sessionType {
            case .checkIn:
                return ["Before we dive in, how are you arriving today?", "What feels heavy right now, and what would help by the end of this check-in?"]
            case .deepDive:
                return ["What situation has been taking the most energy lately?", "Which challenge feels most important to unpack with care right now?"]
            case .freeform:
                return ["What would feel most supportive to focus on first?", "Where would you like to start today so this feels helpful and practical?"]
            case .goalReview:
                return ["Which goal would feel best to revisit today?", "What progress are you proud of, and where do you need support next?"]
            }
        case .strategic:
            switch session.sessionType {
            case .checkIn:
                return ["What decision or outcome has the biggest strategic impact this week?", "If we optimize one priority today, which one changes the most downstream?"]
            case .deepDive:
                return ["What complex challenge do you want to map clearly before acting?", "Which situation needs a sharper strategy right now?"]
            case .freeform:
                return ["What objective should we design a plan around first?", "What result do you want to drive from this session?"]
            case .goalReview:
                return ["Which goal needs a strategy adjustment right now?", "What changed in your context that affects your current plan?"]
            }
        case .auto:
            switch session.sessionType {
            case .checkIn:
                return ["Before we dive in, what is the one thing that would make today feel like progress for you?", "What is the most important thing to get clarity on in this check-in?"]
            case .deepDive:
                return ["What challenge feels most important to unpack deeply right now, and why this one?", "What topic should we go deep on first so this session is worth your time?"]
            case .freeform:
                return ["What would you like to focus on first in this session?", "What feels most important to tackle right now?"]
            case .goalReview:
                return ["Which goal would you like to review, and what changed since your last check-in?", "Which goal needs attention first today, and what has shifted around it?"]
            }
        }
    }

    private func openingQuickReplies(for sessionType: SessionType) -> [QuickReply] {
        let texts: [String]
        switch sessionType {
        case .checkIn:
            texts = ["I feel stuck on priorities", "I need help with a tough conversation", "I want one clear next step"]
        case .deepDive:
            texts = ["Let's unpack a stakeholder issue", "I need to think through trade-offs", "I want to understand what's blocking me"]
        case .freeform:
            texts = ["I need clarity on a decision", "Help me plan this week", "I want feedback on my approach"]
        case .goalReview:
            texts = ["Review progress and gaps", "Adjust my plan for this goal", "Set next milestones"]
        }

        return texts.enumerated().map { index, text in
            let type: QuickReplyType
            switch index {
            case 0: type = .clarification
            case 1: type = .guidance
            default: type = .action
            }
            return QuickReply(id: UUID().uuidString, text: text, type: type)
        }
    }

    @MainActor
    private func streamAssistantResponse(content: String, requestId: String, for session: CoachingSession) async {
        isStreaming = true

        // Create a placeholder assistant message
        let assistantMessage = ChatMessage(
            sessionId: session.id,
            role: .assistant,
            content: "",
            isStreaming: true,
            diagnostics: pendingDiagnostics
        )
        messages.append(assistantMessage)
        pendingDiagnostics = nil

        let stream = streamingService.streamResponse(
            sessionId: session.id,
            requestId: requestId,
            message: content,
            persona: session.persona,
            coachingStyle: selectedCoachingStyle
        )

        streamingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            var streamFailed = false
            var receivedCoachText = false

            do {
                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    guard let lastIndex = self.messages.indices.last else { break }
                    if self.applyDiagnosticsIfMetaToken(token, messageIndex: lastIndex) { continue }
                    if self.applySuggestionsIfSuggestionsToken(token) { continue }
                    if !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        receivedCoachText = true
                    }
                    self.messages[lastIndex].content += token
                }
            } catch {
                if !Task.isCancelled {
                    streamFailed = true
                    self.errorMessage = error.localizedDescription

                    // Mark the user message as failed
                    if let userMessageIndex = self.messages.indices.dropLast().last,
                       self.messages[userMessageIndex].role == .user {
                        self.messages[userMessageIndex].status = .failed
                    }

                    // Remove the failed assistant message
                    if let lastIndex = self.messages.indices.last {
                        self.messages.removeLast()
                    }
                }
            }

            // Finalize the message (only if stream succeeded)
            if !streamFailed, let lastIndex = self.messages.indices.last {
                self.messages[lastIndex].isStreaming = false

                if !receivedCoachText || self.messages[lastIndex].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.messages[lastIndex].content = "Got it. Let's narrow this to one concrete next step you can take today."
                    if self.currentQuickReplies.isEmpty {
                        self.currentQuickReplies = [
                            QuickReply(id: UUID().uuidString, text: "Help me pick the next step", type: .action),
                            QuickReply(id: UUID().uuidString, text: "Give me a 10-minute version", type: .guidance),
                            QuickReply(id: UUID().uuidString, text: "Let's simplify this", type: .clarification),
                        ]
                    }
                }

                // Mark user message as sent
                if let userMessageIndex = self.messages.indices.dropLast().last,
                   self.messages[userMessageIndex].role == .user {
                    self.messages[userMessageIndex].status = .sent
                }
            }

            self.isStreaming = false
            if self.pendingHumanCoachRequest {
                self.pendingHumanCoachRequest = false
                self.evaluateHumanCoachRequest()
            }
            self.streamingTask = nil

            // Auto-save session after each message exchange
            self.saveCurrentSession()
        }
    }

    // MARK: - Quick Reply Support

    func shouldShowQuickReplies(for messageId: String) -> Bool {
        // Show quick replies for the last AI message
        guard let lastMessage = messages.last,
              lastMessage.id == messageId,
              lastMessage.isFromCoach else { return false }
        return showQuickRepliesFor == nil || showQuickRepliesFor == messageId
    }

    func getQuickReplies(for messageId: String) -> [QuickReply] {
        return currentQuickReplies
    }

    func handleQuickReply(_ quickReply: QuickReply) {
        currentInput = quickReply.text
        showQuickRepliesFor = nil
        Task {
            await sendMessage()
        }
    }

    // MARK: - Human Handoff Support

    func requestHumanCoach() {
        // If model is still streaming, defer opening handoff/crisis UI until completion.
        if isStreaming {
            pendingHumanCoachRequest = true
            return
        }

        evaluateHumanCoachRequest()
    }

    private func evaluateHumanCoachRequest() {
        let recentContent = messages.suffix(4).map { $0.content.lowercased() }.joined(separator: " ")
        if containsCrisisSignal(in: recentContent) {
            showCrisisResources = true
            showHandoffOptions = false
            return
        }

        // Not a crisis - show handoff options
        showHandoffOptions = true
    }

    private func containsCrisisSignal(in text: String) -> Bool {
        let t = text.lowercased()
        let crisisKeywords = [
            "suicide", "kill myself", "end it", "hurt myself", "hopeless", "want to die",
            "end my life", "better off dead", "no reason to live"
        ]
        return crisisKeywords.contains { t.contains($0) }
    }

    private func buildDiagnostics(for userMessage: String) -> CoachingDiagnostics {
        let text = userMessage.lowercased()

        let emotion: String
        if ["overwhelmed", "burnout", "anxious", "hopeless"].contains(where: { text.contains($0) }) {
            emotion = "distressed"
        } else if ["not sure", "unclear", "confused", "maybe"].contains(where: { text.contains($0) }) {
            emotion = "uncertain"
        } else {
            emotion = "neutral"
        }

        let goal: String
        if ["promotion", "vp", "director", "career"].contains(where: { text.contains($0) }) {
            goal = "career_advancement"
        } else if ["team", "leadership", "stakeholder", "manager"].contains(where: { text.contains($0) }) {
            goal = "leadership_effectiveness"
        } else {
            goal = "professional_growth"
        }

        return CoachingDiagnostics(
            styleUsed: selectedCoachingStyle.displayName,
            emotionDetected: emotion,
            goalLink: goal,
            goalAnchor: nil,
            goalHierarchySummary: nil,
            progressiveSkillSummary: nil,
            outcomePredictionSummary: nil
        )
    }

    private func applyDiagnosticsIfMetaToken(_ token: String, messageIndex: Int) -> Bool {
        guard token.hasPrefix("__META__:") else { return false }
        let raw = String(token.dropFirst("__META__:".count))
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return true
        }

        let style = (json["style_used"] as? String) ?? selectedCoachingStyle.displayName
        let emotion = (json["emotion_detected"] as? String) ?? "neutral"
        let goal = (json["goal_link"] as? String) ?? "professional_growth"

        let goalAnchor = json["goal_anchor"] as? String
        let goalHierarchySummary = summarizeAny(json["goal_hierarchy"])
        let progressiveSkillSummary = summarizeAny(json["progressive_skill_building"])
        let outcomePredictionSummary = summarizeAny(json["outcome_prediction"])
        let recommendedStyleShift = json["recommended_style_shift"] as? String
        let riskLevel = (json["outcome_prediction"] as? [String: Any])?["risk_level"] as? String

        if let replies = json["quick_replies"] as? [String], !replies.isEmpty {
            currentQuickReplies = replies.prefix(4).enumerated().map { index, text in
                let type: QuickReplyType
                switch index {
                case 0: type = .clarification
                case 1: type = .guidance
                case 2: type = .action
                default: type = .reflection
                }
                return QuickReply(id: UUID().uuidString, text: text, type: type)
            }
        }

        messages[messageIndex].diagnostics = CoachingDiagnostics(
            styleUsed: style,
            emotionDetected: emotion,
            goalLink: goal,
            goalAnchor: goalAnchor,
            goalHierarchySummary: goalHierarchySummary,
            progressiveSkillSummary: progressiveSkillSummary,
            outcomePredictionSummary: outcomePredictionSummary,
            riskLevel: riskLevel,
            recommendedStyleShift: recommendedStyleShift
        )

        return true
    }

    /// Parse a __SUGGESTIONS__: token emitted by the mock (and eventually real) service.
    /// Returns true if the token was consumed (caller should not append it to message content).
    @MainActor
    private func applySuggestionsIfSuggestionsToken(_ token: String) -> Bool {
        guard token.hasPrefix("__SUGGESTIONS__:") else { return false }
        let raw = String(token.dropFirst("__SUGGESTIONS__:".count))
        guard let data = raw.data(using: .utf8),
              let texts = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return true
        }
        currentQuickReplies = texts.prefix(4).enumerated().map { index, text in
            QuickReply(id: UUID().uuidString, text: text, type: .clarification)
        }
        return true
    }

    private func summarizeAny(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let s = value as? String {
            return s
        }
        if let data = try? JSONSerialization.data(withJSONObject: value, options: []),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return nil
    }

    func dismissHandoffOptions() {
        showHandoffOptions = false
    }

    func navigateToSubscription() {
        // TODO: Navigate to subscription view
        showHandoffOptions = false
    }

    func openCoachChat() {
        // TODO: Open in-app chat with human coach
        showHandoffOptions = false
    }

    func openCalendly() {
        // TODO: Open Calendly scheduling
        // Could use UIApplication.shared.open(URL(string: "https://calendly.com/coaching-career")!)
        showHandoffOptions = false
    }

    // MARK: - Voice Input Support

    @MainActor
    func startVoiceInput() {
        isVoiceMode = true
        voiceInputManager = VoiceInputManager()
        Task {
            do {
                try await voiceInputManager?.startVoiceInput()
            } catch {
                self.errorMessage = error.localizedDescription
                isVoiceMode = false
            }
        }
    }

    @MainActor
    func endVoiceInput() {
        voiceInputManager?.stopVoiceInput()
        // Get final transcription
        if let transcript = voiceInputManager?.transcribedText, !transcript.isEmpty {
            currentInput = transcript
        }
        isVoiceMode = false
        // Auto-send if there's content
        if !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                await sendMessage()
            }
        }
    }

    // MARK: - Session Persistence

    @MainActor
    private func saveCurrentSession() {
        guard let session = currentSession, !messages.isEmpty else { return }
        Task { @MainActor in
            do {
                try await historyStorage.saveSession(session, messages: messages)
                self.lastSavedAt = Date()
            } catch {
                print("[ChatViewModel] Failed to save session: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    func generateSessionSummary() async {
        guard !messages.isEmpty else { return }
        
        isGeneratingSummary = true
        defer { isGeneratingSummary = false }
        
        do {
            let apiMessages = messages.map { message in
                ["role": message.role.rawValue, "content": message.content]
            }
            
            let requestBody: [String: Any] = [
                "messages": apiMessages,
                "userId": "mock-user-001"
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            let envRaw = UserDefaults.standard.string(forKey: "selectedAPIEnvironment") ?? "Local"
            let env = APIEnvironment(rawValue: envRaw) ?? .localhost
            
            guard let url = URL(string: "\(env.baseURL)/chat/session-summary") else {
                errorMessage = "Invalid API URL"
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let summary = try JSONDecoder().decode(CoachingSessionSummary.self, from: data)
            
            self.sessionSummary = summary
        } catch {
            errorMessage = "Failed to generate summary: \(error.localizedDescription)"
        }
    }

    @MainActor
    func loadSessionHistory(sessionId: String) async {
        isLoading = true
        do {
            if let (session, savedMessages) = try await historyStorage.loadSession(id: sessionId) {
                currentSession = session
                messages = savedMessages
                if session.isActive {
                    startTimer()
                }
            }
        } catch {
            errorMessage = "Failed to load session: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - Quick Reply Model

enum QuickReplyType {
    case goalOriented
    case clarification
    case guidance
    case action
    case reflection
}

struct QuickReply: Identifiable {
    let id: String
    let text: String
    let type: QuickReplyType
}

// MARK: - Crisis Resource Model

struct CrisisResourceModel: Identifiable {
    let id = UUID()
    let name: String
    let phone: String?
    let textNumber: String?
    let available: String
}
