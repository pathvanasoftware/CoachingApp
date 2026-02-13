//
//  VoiceInputManager.swift
//  AI Coaching App
//
//  Created by 刘亦菲 on 2026-02-13.
//

import Foundation
import Speech
import AVFoundation

// MARK: - VoiceInputManager
@MainActor
class VoiceInputManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isActive: Bool = false
    @Published var transcribedText: String = ""
    @Published var error: String?

    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?

    // MARK: - Callbacks
    var onTranscriptionComplete: ((String) -> Void)?

    // MARK: - Initialization
    override init() {
        // Initialize speech recognizer with current locale
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        super.init()
    }

    // MARK: - Request Authorization
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Start Voice Input
    func startVoiceInput() async throws {
        // Stop any existing session
        stopVoiceInput()

        // Check authorization
        let isAuthorized = await requestAuthorization()
        guard isAuthorized else {
            throw VoiceInputError.notAuthorized
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Initialize audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw VoiceInputError.audioEngineFailed
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceInputError.recognitionRequestFailed
        }

        recognitionRequest.shouldReportPartialResults = true

        // Configure speech recognizer
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceInputError.speechRecognizerUnavailable
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                }

                if let error = error {
                    self?.error = error.localizedDescription
                    self?.stopVoiceInput()
                }

                // Check if final result
                if let result = result, result.isFinal {
                    self?.onTranscriptionComplete?(result.bestTranscription.formattedString)
                    self?.stopVoiceInput()
                }
            }
        }

        // Setup audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isActive = true
        transcribedText = ""
        error = nil
    }

    // MARK: - Stop Voice Input
    func stopVoiceInput() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }

        isActive = false
    }

    // MARK: - Reset
    func reset() {
        transcribedText = ""
        error = nil
    }
}

// MARK: - VoiceInputError
enum VoiceInputError: LocalizedError {
    case notAuthorized
    case audioEngineFailed
    case recognitionRequestFailed
    case speechRecognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized"
        case .audioEngineFailed:
            return "Failed to initialize audio engine"
        case .recognitionRequestFailed:
            return "Failed to create recognition request"
        case .speechRecognizerUnavailable:
            return "Speech recognizer is not available"
        }
    }
}
