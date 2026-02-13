import Foundation
import Speech
import AVFoundation

// MARK: - Speech Recognition Service

@Observable
final class SpeechRecognitionService: NSObject, @unchecked Sendable {

    // MARK: - Observable Properties

    private(set) var isListening: Bool = false
    private(set) var transcribedText: String = ""
    private(set) var isAuthorized: Bool = false
    private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    private(set) var error: String?

    // MARK: - Configuration

    /// Duration of silence (in seconds) before triggering an automatic send.
    var silenceThreshold: TimeInterval = 2.0

    /// Locale for speech recognition.
    var locale: Locale = .current

    // MARK: - Callbacks

    /// Called when silence is detected (user paused for `silenceThreshold` seconds).
    var onSilenceDetected: ((String) -> Void)?

    /// Called with partial transcription results as the user speaks.
    var onPartialResult: ((String) -> Void)?

    // MARK: - Private Properties

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var lastTranscription: String = ""

    // MARK: - Init

    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    init(locale: Locale) {
        self.locale = locale
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                self.authorizationStatus = status
                self.isAuthorized = (status == .authorized)

                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Also request microphone access (required for audio recording).
    func requestMicrophoneAccess() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Start Listening

    func startListening() throws {
        guard isAuthorized else {
            throw SpeechRecognitionError.notAuthorized
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }

        // Stop any existing task
        stopListening()

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            throw SpeechRecognitionError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                self.transcribedText = text
                self.onPartialResult?(text)

                // Reset silence timer on new speech
                self.resetSilenceTimer()

                if result.isFinal {
                    self.handleFinalResult(text)
                }
            }

            if let error {
                self.handleRecognitionError(error)
            }
        }

        // Install audio tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        error = nil

        // Start initial silence timer
        resetSilenceTimer()
    }

    // MARK: - Stop Listening

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        isListening = false
    }

    // MARK: - Reset

    /// Clear the current transcription and prepare for a new utterance.
    func resetTranscription() {
        transcribedText = ""
        lastTranscription = ""
    }

    // MARK: - Private: Silence Detection

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()

        DispatchQueue.main.async { [weak self] in
            guard let self, self.isListening else { return }

            self.silenceTimer = Timer.scheduledTimer(
                withTimeInterval: self.silenceThreshold,
                repeats: false
            ) { [weak self] _ in
                guard let self else { return }
                self.handleSilenceDetected()
            }
        }
    }

    private func handleSilenceDetected() {
        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty, text != lastTranscription else {
            return
        }

        lastTranscription = text
        onSilenceDetected?(text)
    }

    // MARK: - Private: Result Handling

    private func handleFinalResult(_ text: String) {
        // Final result received; recognition task ended naturally
        isListening = false
        silenceTimer?.invalidate()
    }

    private func handleRecognitionError(_ recognitionError: Error) {
        error = recognitionError.localizedDescription
        stopListening()
    }
}

// MARK: - Speech Recognition Error

enum SpeechRecognitionError: Error, LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case requestCreationFailed
    case audioEngineFailed
    case microphoneAccessDenied

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized. Please enable it in Settings."
        case .recognizerUnavailable:
            return "Speech recognition is not available on this device."
        case .requestCreationFailed:
            return "Failed to create the speech recognition request."
        case .audioEngineFailed:
            return "The audio engine failed to start."
        case .microphoneAccessDenied:
            return "Microphone access is required for voice input. Please enable it in Settings."
        }
    }
}
