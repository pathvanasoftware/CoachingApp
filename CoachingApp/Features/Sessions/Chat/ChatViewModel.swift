import Foundation
import UIKit

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

    private let chatService: ChatServiceProtocol
    private let streamingService: StreamingServiceProtocol
    private let historyStorage = ChatHistoryStorage.shared

    // MARK: - Private State

    private var timerTask: Task<Void, Never>?
    private var streamingTask: Task<Void, Never>?
    private var voiceInputManager: VoiceInputManager?
    private var pendingHumanCoachRequest: Bool = false
    private var pendingDiagnostics: CoachingDiagnostics?

    // Quick reply suggestions based on context
    private let quickReplySuggestions: [QuickReply] = [
        QuickReply(id: "1", text: "Tell me more", type: .clarification),
        QuickReply(id: "2", text: "What should I do next?", type: .action),
        QuickReply(id: "3", text: "How can I improve?", type: .guidance),
        QuickReply(id: "4", text: "I'd like to talk to a human coach", type: .reflection)
    ]

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
        await streamAssistantResponse(content: content, for: session)

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
        await streamAssistantResponse(content: content, for: session)

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
    private func streamInitialGreeting(for session: CoachingSession) async {
        isStreaming = true

        // Create a placeholder assistant message
        let assistantMessage = ChatMessage(
            sessionId: session.id,
            role: .assistant,
            content: "",
            isStreaming: true,
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

        let stream = streamingService.streamResponse(
            sessionId: session.id,
            message: "",
            persona: session.persona,
            coachingStyle: selectedCoachingStyle
        )

        do {
            for try await token in stream {
                guard let lastIndex = messages.indices.last else { break }
                if applyDiagnosticsIfMetaToken(token, messageIndex: lastIndex) {
                    continue
                }
                messages[lastIndex].content += token
            }
        } catch {
            errorMessage = "Streaming error: \(error.localizedDescription)"
        }

        // Finalize the message
        if let lastIndex = messages.indices.last {
            messages[lastIndex].isStreaming = false
        }

        isStreaming = false
        if pendingHumanCoachRequest {
            pendingHumanCoachRequest = false
            evaluateHumanCoachRequest()
        }
    }

    @MainActor
    private func streamAssistantResponse(content: String, for session: CoachingSession) async {
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
            message: content,
            persona: session.persona,
            coachingStyle: selectedCoachingStyle
        )

        streamingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            var streamFailed = false

            do {
                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    guard let lastIndex = self.messages.indices.last else { break }
                    if self.applyDiagnosticsIfMetaToken(token, messageIndex: lastIndex) {
                        continue
                    }
                    self.messages[lastIndex].content += token
                }
            } catch {
                if !Task.isCancelled {
                    streamFailed = true
                    self.errorMessage = "Network error. Please check your connection and retry."

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
        return quickReplySuggestions
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
import Foundation

// MARK: - Chat History Storage

actor ChatHistoryStorage {
    static let shared = ChatHistoryStorage()
    
    private let fileManager = FileManager.default
    private let storageDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        storageDirectory = appSupport.appendingPathComponent("ChatHistory", isDirectory: true)
        
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Save Session
    
    func saveSession(_ session: CoachingSession, messages: [ChatMessage]) async throws {
        let sessionData = SessionData(session: session, messages: messages, savedAt: Date())
        let data = try encoder.encode(sessionData)
        let fileURL = storageDirectory.appendingPathComponent("\(session.id).json")
        try data.write(to: fileURL)
    }
    
    // MARK: - Load Session
    
    func loadSession(id: String) async throws -> (CoachingSession, [ChatMessage])? {
        let fileURL = storageDirectory.appendingPathComponent("\(id).json")
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        let sessionData = try decoder.decode(SessionData.self, from: data)
        return (sessionData.session, sessionData.messages)
    }
    
    // MARK: - List Sessions
    
    func listSessions() async throws -> [SessionSummary] {
        let contents = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
        
        var summaries: [SessionSummary] = []
        for fileURL in contents where fileURL.pathExtension == "json" {
            if let data = try? Data(contentsOf: fileURL),
               let sessionData = try? decoder.decode(SessionData.self, from: data) {
                let summary = SessionSummary(
                    id: sessionData.session.id,
                    sessionType: sessionData.session.sessionType,
                    startedAt: sessionData.session.startedAt,
                    lastMessageAt: sessionData.savedAt,
                    messageCount: sessionData.messages.count
                )
                summaries.append(summary)
            }
        }
        
        return summaries.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }
    
    // MARK: - Delete Session
    
    func deleteSession(id: String) async throws {
        let fileURL = storageDirectory.appendingPathComponent("\(id).json")
        try fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - Clear All
    
    func clearAll() async throws {
        let contents = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: nil)
        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
    }
}

// MARK: - Session Data Model

private struct SessionData: Codable {
    let session: CoachingSession
    let messages: [ChatMessage]
    let savedAt: Date
}

// MARK: - Session Summary

struct SessionSummary: Identifiable, Codable {
    let id: String
    let sessionType: SessionType
    let startedAt: Date
    let lastMessageAt: Date
    let messageCount: Int
}
