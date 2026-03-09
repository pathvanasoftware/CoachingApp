import Foundation
import SwiftUI

// MARK: - Voice State

enum VoiceState: Equatable {
    case idle
    case listening
    case processing
    case speaking
    case paused

    var statusText: String {
        switch self {
        case .idle: return "Tap the microphone to start"
        case .listening: return "Listening..."
        case .processing: return "Thinking..."
        case .speaking: return "Speaking..."
        case .paused: return "Session paused"
        }
    }

    var icon: String {
        switch self {
        case .idle: return "mic.fill"
        case .listening: return "mic.fill"
        case .processing: return "brain"
        case .speaking: return "speaker.wave.3.fill"
        case .paused: return "pause.circle.fill"
        }
    }
}

// MARK: - Voice View Model

@Observable
final class VoiceViewModel {

    // MARK: - State

    var voiceState: VoiceState = .idle
    var transcribedText: String = ""
    var currentResponse: String = ""
    var messages: [ChatMessage] = []
    var isSessionActive: Bool = false
    var errorMessage: String?
    var amplitude: CGFloat = 0.0
    var currentSession: CoachingSession?
    var selectedCoachingStyle: CoachingStyle = .auto

    // MARK: - Private

    private let speechRecognition: SpeechRecognitionService
    private let textToSpeech: TextToSpeechService
    var chatService: ChatServiceProtocol
    var streamingService: StreamingServiceProtocol
    private let historyStorage = ChatHistoryStorage.shared
    private let analytics = AnalyticsService.shared
    private var amplitudeTimer: Timer?
    private var processingTask: Task<Void, Never>?

    let persona: CoachingPersonaType

    // MARK: - Init

    init(
        persona: CoachingPersonaType = .directChallenger,
        speechRecognition: SpeechRecognitionService = SpeechRecognitionService(),
        textToSpeech: TextToSpeechService = TextToSpeechService(),
        chatService: ChatServiceProtocol = MockChatService.shared,
        streamingService: StreamingServiceProtocol = MockChatService.shared
    ) {
        self.persona = persona
        self.speechRecognition = speechRecognition
        self.textToSpeech = textToSpeech
        self.chatService = chatService
        self.streamingService = streamingService

        self.speechRecognition.onPartialResult = { [weak self] text in
            Task { @MainActor in
                self?.transcribedText = text
            }
        }
        self.speechRecognition.onSilenceDetected = { [weak self] text in
            Task { @MainActor in
                self?.handleSilenceDetected(text)
            }
        }
        self.textToSpeech.onSpeechFinished = { [weak self] in
            Task { @MainActor in
                self?.handleSpeechFinished()
            }
        }
    }

    // MARK: - Session Lifecycle

    @MainActor
    func beginSession(
        userId: String,
        existingSession: CoachingSession? = nil,
        existingMessages: [ChatMessage] = []
    ) async {
        errorMessage = nil

        let speechAuthorized = await speechRecognition.requestAuthorization()
        guard speechAuthorized else {
            errorMessage = SpeechRecognitionError.notAuthorized.errorDescription
            return
        }

        let microphoneAuthorized = await speechRecognition.requestMicrophoneAccess()
        guard microphoneAuthorized else {
            errorMessage = SpeechRecognitionError.microphoneAccessDenied.errorDescription
            return
        }

        if let existingSession {
            currentSession = existingSession
            messages = existingMessages
            isSessionActive = existingSession.isActive
            if let lastCoachMessage = messages.last(where: \.isFromCoach) {
                currentResponse = lastCoachMessage.content
            }
            return
        }

        do {
            let session = try await chatService.startSession(
                userId: userId,
                persona: persona,
                sessionType: .freeform,
                inputMode: .voice
            )
            currentSession = session
            isSessionActive = true
            analytics.track("voice_session_started", properties: [
                "session_id": session.id,
                "persona": persona.rawValue,
            ])

            let welcomeMessage = ChatMessage(
                sessionId: session.id,
                role: .assistant,
                content: "I'm ready to coach you. What's on your mind?"
            )
            messages = [welcomeMessage]
            currentResponse = welcomeMessage.content
            await saveCurrentSession()
            startSpeaking(text: welcomeMessage.content)
        } catch {
            errorMessage = "Failed to start session: \(error.localizedDescription)"
            analytics.track("voice_session_start_failed", properties: [
                "persona": persona.rawValue,
                "error": error.localizedDescription,
            ])
        }
    }

    @MainActor
    func endSession() async {
        stopListening()
        stopSpeaking()
        processingTask?.cancel()
        stopAmplitudeSimulation()

        if let session = currentSession, session.isActive {
            do {
                let endedSession = try await chatService.endSession(sessionId: session.id)
                currentSession = endedSession
                isSessionActive = false
                analytics.track("voice_session_ended", properties: [
                    "session_id": session.id,
                    "message_count": messages.count,
                ])
                await saveCurrentSession()
            } catch {
                errorMessage = "Failed to end session: \(error.localizedDescription)"
                analytics.track("voice_session_end_failed", properties: [
                    "session_id": session.id,
                    "error": error.localizedDescription,
                ])
            }
        }

        voiceState = .idle
    }

    // MARK: - Listening

    @MainActor
    func startListening() {
        guard isSessionActive else { return }
        guard voiceState == .idle || voiceState == .paused else { return }

        errorMessage = nil
        transcribedText = ""
        speechRecognition.resetTranscription()

        do {
            try speechRecognition.startListening()
            voiceState = .listening
            startAmplitudeSimulation()
            analytics.track("voice_listening_started", properties: [
                "session_id": currentSession?.id,
            ])
        } catch {
            errorMessage = error.localizedDescription
            voiceState = .idle
            stopAmplitudeSimulation()
            analytics.track("voice_listening_failed", properties: [
                "session_id": currentSession?.id,
                "error": error.localizedDescription,
            ])
        }
    }

    @MainActor
    func stopListening() {
        guard voiceState == .listening else { return }

        speechRecognition.stopListening()
        stopAmplitudeSimulation()

        let spokenText = speechRecognition.transcribedText.isEmpty
            ? transcribedText
            : speechRecognition.transcribedText

        transcribedText = spokenText
        guard !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            voiceState = .idle
            return
        }

        voiceState = .processing
        analytics.track("voice_transcription_captured", properties: [
            "session_id": currentSession?.id,
            "text_length": spokenText.count,
        ])
        processTranscription(spokenText)
    }

    @MainActor
    private func handleSilenceDetected(_ text: String) {
        guard voiceState == .listening else { return }
        transcribedText = text
        stopListening()
    }

    // MARK: - Processing

    @MainActor
    func processTranscription(_ spokenText: String? = nil) {
        guard let sessionId = currentSession?.id else {
            voiceState = .idle
            return
        }

        let content = (spokenText ?? transcribedText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            voiceState = .idle
            return
        }

        let userMessage = ChatMessage(
            sessionId: sessionId,
            role: .user,
            content: content,
            status: .sending
        )
        messages.append(userMessage)
        transcribedText = content
        currentResponse = ""

        let stream = streamingService.streamResponse(
            sessionId: sessionId,
            requestId: userMessage.id,
            message: content,
            persona: persona,
            coachingStyle: selectedCoachingStyle
        )

        let assistantMessage = ChatMessage(
            sessionId: sessionId,
            role: .assistant,
            content: "",
            isStreaming: true
        )
        messages.append(assistantMessage)

        processingTask?.cancel()
        processingTask = Task { @MainActor [weak self] in
            guard let self else { return }

            var streamFailed = false

            do {
                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    guard let lastIndex = self.messages.indices.last else { break }
                    guard !token.hasPrefix("__META__:") else { continue }
                    if token.hasPrefix("__SUGGESTIONS__:") { continue }
                    self.messages[lastIndex].content += token
                }
            } catch {
                streamFailed = true
                self.errorMessage = "Failed to get response: \(error.localizedDescription)"
            }

            guard !Task.isCancelled else { return }

            if streamFailed {
                if let assistantIndex = self.messages.indices.last,
                   self.messages[assistantIndex].role == .assistant,
                   self.messages[assistantIndex].isStreaming {
                    self.messages.removeLast()
                }
                if self.messages.indices.contains(self.messages.count - 1),
                   self.messages.last?.role == .user {
                    self.messages[self.messages.count - 1].status = .failed
                }
                self.voiceState = .idle
                await self.saveCurrentSession()
                return
            }

            if let assistantIndex = self.messages.indices.last,
               self.messages[assistantIndex].role == .assistant {
                self.messages[assistantIndex].isStreaming = false
                if self.messages[assistantIndex].content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.messages[assistantIndex].content = "Let's make this concrete. What's the one decision or action you want to leave with?"
                }
                self.currentResponse = self.messages[assistantIndex].content
            }

            if self.messages.count >= 2 {
                let userIndex = self.messages.count - 2
                if self.messages.indices.contains(userIndex),
                   self.messages[userIndex].role == .user {
                    self.messages[userIndex].status = .sent
                }
            }

            await self.saveCurrentSession()
            self.startSpeaking(text: self.currentResponse)
        }
    }

    // MARK: - Speaking

    @MainActor
    func startSpeaking(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            voiceState = .idle
            return
        }

        stopAmplitudeSimulation()
        voiceState = .speaking
        startAmplitudeSimulation()
        textToSpeech.speak(text: text)
    }

    @MainActor
    func stopSpeaking() {
        textToSpeech.stop()
        stopAmplitudeSimulation()
        if voiceState == .speaking {
            voiceState = .idle
        }
    }

    @MainActor
    private func handleSpeechFinished() {
        stopAmplitudeSimulation()
        if voiceState == .speaking {
            voiceState = .idle
        }
    }

    // MARK: - Pause / Resume

    @MainActor
    func pauseSession() {
        let previousState = voiceState
        voiceState = .paused
        stopAmplitudeSimulation()

        if previousState == .listening {
            speechRecognition.stopListening()
        }
        if previousState == .speaking {
            textToSpeech.pause()
        }
    }

    @MainActor
    func resumeSession() {
        guard voiceState == .paused else { return }

        if textToSpeech.isPaused {
            voiceState = .speaking
            startAmplitudeSimulation()
            textToSpeech.resume()
            return
        }

        voiceState = .idle
    }

    // MARK: - Persistence

    @MainActor
    private func saveCurrentSession() async {
        guard let currentSession else { return }
        var session = currentSession
        session.messageCount = messages.count
        if !session.isActive {
            session.durationSeconds = Int(Date().timeIntervalSince(session.startedAt))
        }
        self.currentSession = session

        do {
            try await historyStorage.saveSession(session, messages: messages)
        } catch {
            print("[VoiceViewModel] Failed to save session: \(error.localizedDescription)")
        }
    }

    // MARK: - Amplitude Simulation

    private func startAmplitudeSimulation() {
        stopAmplitudeSimulation()
        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.amplitude = CGFloat.random(in: 0.2...1.0)
            }
        }
    }

    private func stopAmplitudeSimulation() {
        amplitudeTimer?.invalidate()
        amplitudeTimer = nil
        amplitude = 0.0
    }

    deinit {
        processingTask?.cancel()
        stopAmplitudeSimulation()
        speechRecognition.stopListening()
        textToSpeech.stop()
    }
}
