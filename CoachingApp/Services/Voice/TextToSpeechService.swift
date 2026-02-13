import Foundation
import AVFoundation

// MARK: - Text to Speech Service

@Observable
final class TextToSpeechService: NSObject, @unchecked Sendable {

    // MARK: - Observable Properties

    private(set) var isSpeaking: Bool = false
    private(set) var currentUtterance: String?
    private(set) var isPaused: Bool = false

    // MARK: - Configuration

    /// Speech rate (0.0 to 1.0). Default is the system default rate.
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate

    /// Speech pitch multiplier (0.5 to 2.0). Default is 1.0.
    var pitchMultiplier: Float = 1.0

    /// Speech volume (0.0 to 1.0). Default is 1.0.
    var volume: Float = 1.0

    /// The preferred voice identifier. Nil uses the system default.
    var preferredVoiceIdentifier: String?

    // MARK: - Callbacks

    /// Called when speech finishes naturally (not cancelled).
    var onSpeechFinished: (() -> Void)?

    /// Called when a word boundary is reached, with the character range.
    var onWordBoundary: ((NSRange) -> Void)?

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Init

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Speak

    /// Speak the given text using the configured voice and rate.
    func speak(text: String) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.volume = volume

        // Set voice
        if let voiceId = preferredVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            // Use a high-quality English voice if available
            utterance.voice = Self.preferredEnglishVoice()
        }

        currentUtterance = text
        synthesizer.speak(utterance)
    }

    // MARK: - Stop

    /// Stop speaking immediately.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        currentUtterance = nil
    }

    // MARK: - Pause / Resume

    /// Pause the current speech.
    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
    }

    /// Resume paused speech.
    func resume() {
        if isPaused {
            synthesizer.continueSpeaking()
        }
    }

    // MARK: - Rate Control

    /// Set the speech rate with a named preset.
    func setRate(_ preset: SpeechRate) {
        rate = preset.value
    }

    // MARK: - Voice Selection

    /// Set the voice by identifier string.
    func setVoice(identifier: String) {
        preferredVoiceIdentifier = identifier
    }

    /// Get all available voices for the given language.
    static func availableVoices(for language: String = "en-US") -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix(language.prefix(2).lowercased())
        }
    }

    /// Returns a preferred high-quality English voice, or nil.
    static func preferredEnglishVoice() -> AVSpeechSynthesisVoice? {
        // Prefer premium/enhanced voices
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.hasPrefix("en") && $0.quality == .enhanced
        }
        return voices.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        isSpeaking = true
        isPaused = false
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        isSpeaking = false
        isPaused = false
        currentUtterance = nil
        onSpeechFinished?()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        isSpeaking = false
        isPaused = false
        currentUtterance = nil
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didPause utterance: AVSpeechUtterance
    ) {
        isPaused = true
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didContinue utterance: AVSpeechUtterance
    ) {
        isPaused = false
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        onWordBoundary?(characterRange)
    }
}

// MARK: - Speech Rate Presets

enum SpeechRate {
    case slow
    case normal
    case fast
    case veryFast

    var value: Float {
        switch self {
        case .slow:
            return AVSpeechUtteranceDefaultSpeechRate * 0.7
        case .normal:
            return AVSpeechUtteranceDefaultSpeechRate
        case .fast:
            return AVSpeechUtteranceDefaultSpeechRate * 1.3
        case .veryFast:
            return AVSpeechUtteranceDefaultSpeechRate * 1.6
        }
    }

    var displayName: String {
        switch self {
        case .slow: return "Slow"
        case .normal: return "Normal"
        case .fast: return "Fast"
        case .veryFast: return "Very Fast"
        }
    }
}
