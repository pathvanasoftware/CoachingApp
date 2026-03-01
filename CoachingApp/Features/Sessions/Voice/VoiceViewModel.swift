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

    // MARK: - Private

    private let speechRecognition: SpeechRecognitionService
    private let textToSpeech: TextToSpeechService
    private let chatService: ChatServiceProtocol
    private var currentSession: CoachingSession?
    private var amplitudeTimer: Timer?

    let persona: CoachingPersonaType

    // MARK: - Init

    init(
        persona: CoachingPersonaType = .directChallenger,
        speechRecognition: SpeechRecognitionService = SpeechRecognitionService(),
        textToSpeech: TextToSpeechService = TextToSpeechService(),
        chatService: ChatServiceProtocol = MockChatService.shared
    ) {
        self.persona = persona
        self.speechRecognition = speechRecognition
        self.textToSpeech = textToSpeech
        self.chatService = chatService
    }

    // MARK: - Session Lifecycle

    func beginSession() async {
        do {
            let session = try await chatService.startSession(
                userId: "current-user",
                persona: persona,
                sessionType: .freeform,
                inputMode: .voice
            )
            currentSession = session
            isSessionActive = true

            // Add a welcome message
            let welcomeMessage = ChatMessage(
                sessionId: session.id,
                role: .assistant,
                content: "I'm ready to coach you. What's on your mind?"
            )
            messages.append(welcomeMessage)
            currentResponse = welcomeMessage.content

            voiceState = .speaking
            textToSpeech.speak(text:welcomeMessage.content)

            // Simulate TTS finishing
            try? await Task.sleep(for: .seconds(2))
            if voiceState == .speaking {
                textToSpeech.stop()
                voiceState = .idle
            }
        } catch {
            errorMessage = "Failed to start session: \(error.localizedDescription)"
        }
    }

    func endSession() async {
        stopListening()
        textToSpeech.stop()
        stopAmplitudeSimulation()

        if let sessionId = currentSession?.id {
            do {
                _ = try await chatService.endSession(sessionId: sessionId)
            } catch {
                print("[VoiceViewModel] Failed to end session: \(error.localizedDescription)")
            }
        }

        voiceState = .idle
        isSessionActive = false
        currentSession = nil
    }

    // MARK: - Listening

    func startListening() {
        guard voiceState == .idle || voiceState == .paused else { return }

        transcribedText = ""
        try? speechRecognition.startListening()
        voiceState = .listening
        startAmplitudeSimulation()
    }

    func stopListening() {
        guard voiceState == .listening else { return }

        speechRecognition.stopListening()
        stopAmplitudeSimulation()

        let spokenText = speechRecognition.transcribedText.isEmpty
            ? transcribedText
            : speechRecognition.transcribedText

        if spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            voiceState = .idle
            return
        }

        transcribedText = spokenText
        voiceState = .processing
        processTranscription()
    }

    // MARK: - Processing

    func processTranscription() {
        guard let sessionId = currentSession?.id else {
            voiceState = .idle
            return
        }

        let userMessage = ChatMessage(
            sessionId: sessionId,
            role: .user,
            content: transcribedText
        )
        messages.append(userMessage)

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard let sessionId = self.currentSession?.id else { return }
            do {
                let response = try await self.chatService.sendMessage(
                    sessionId: sessionId,
                    content: self.transcribedText
                )

                self.messages.append(response)
                self.currentResponse = response.content
                self.startSpeaking(text: response.content)
            } catch {
                self.errorMessage = "Failed to get response: \(error.localizedDescription)"
                self.voiceState = .idle
            }
        }
    }

    // MARK: - Speaking

    func startSpeaking(text: String) {
        voiceState = .speaking
        textToSpeech.speak(text:text)
        startAmplitudeSimulation()

        // Simulate TTS completion based on text length
        let estimatedDuration = max(2.0, Double(text.count) / 30.0)
        Task {
            try? await Task.sleep(for: .seconds(estimatedDuration))
            if voiceState == .speaking {
                textToSpeech.stop()
                stopAmplitudeSimulation()
                voiceState = .idle
            }
        }
    }

    // MARK: - Pause / Resume

    func pauseSession() {
        let previousState = voiceState
        voiceState = .paused
        stopAmplitudeSimulation()

        if previousState == .listening {
            speechRecognition.stopListening()
        }
        if previousState == .speaking {
            textToSpeech.stop()
        }
    }

    func resumeSession() {
        guard voiceState == .paused else { return }
        voiceState = .idle
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
        stopAmplitudeSimulation()
        stopListening()
    }
}
