import SwiftUI
import AVFoundation

struct VoiceSettingsView: View {
    @Bindable var viewModel: ProfileViewModel

    @State private var autoSendAfterSilence = true
    @State private var silenceDetectionDuration: Double = 1.5
    @State private var selectedVoiceIdentifier: String = ""
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

    var body: some View {
        List {
            // Voice Mode Toggle
            voiceModeSection

            if viewModel.voiceEnabled {
                // Speech Rate
                speechRateSection

                // Voice Selection
                voiceSelectionSection

                // Auto-Send Settings
                autoSendSection

                // Test Voice
                testVoiceSection
            }
        }
        .navigationTitle("Voice Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAvailableVoices()
        }
    }

    // MARK: - Voice Mode Section

    private var voiceModeSection: some View {
        Section {
            Toggle(isOn: $viewModel.voiceEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text("Voice Mode")
                            .font(AppFonts.body)
                        Text("Enable voice input and text-to-speech responses")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } icon: {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }

    // MARK: - Speech Rate Section

    private var speechRateSection: some View {
        Section("Speech Rate") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    Image(systemName: "tortoise.fill")
                        .foregroundStyle(AppTheme.textTertiary)

                    Slider(value: $viewModel.voiceRate, in: 0.3...0.7, step: 0.05)

                    Image(systemName: "hare.fill")
                        .foregroundStyle(AppTheme.textTertiary)
                }

                Text("Rate: \(String(format: "%.2f", viewModel.voiceRate))")
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Voice Selection Section

    private var voiceSelectionSection: some View {
        Section("Voice") {
            if availableVoices.isEmpty {
                Text("No voices available")
                    .font(AppFonts.body)
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                ForEach(availableVoices, id: \.identifier) { voice in
                    Button {
                        selectedVoiceIdentifier = voice.identifier
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                Text(voice.name)
                                    .font(AppFonts.body)
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text(voiceQualityLabel(for: voice))
                                    .font(AppFonts.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()

                            if selectedVoiceIdentifier == voice.identifier {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Auto-Send Section

    private var autoSendSection: some View {
        Section {
            Toggle(isOn: $autoSendAfterSilence) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("Auto-send after silence")
                        .font(AppFonts.body)
                    Text("Automatically send your message after detecting silence")
                        .font(AppFonts.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            if autoSendAfterSilence {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Silence detection duration")
                        .font(AppFonts.body)

                    Picker("Duration", selection: $silenceDetectionDuration) {
                        Text("1.0s").tag(1.0)
                        Text("1.5s").tag(1.5)
                        Text("2.0s").tag(2.0)
                        Text("2.5s").tag(2.5)
                        Text("3.0s").tag(3.0)
                    }
                    .pickerStyle(.segmented)
                }
            }
        } header: {
            Text("Auto-Send")
        }
    }

    // MARK: - Test Voice Section

    private var testVoiceSection: some View {
        Section {
            Button {
                testVoice()
            } label: {
                HStack {
                    Spacer()
                    Label("Test Voice", systemImage: "play.circle.fill")
                        .font(AppFonts.headline)
                        .foregroundStyle(AppTheme.primary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadAvailableVoices() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        availableVoices = allVoices
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }

        if selectedVoiceIdentifier.isEmpty, let firstVoice = availableVoices.first {
            selectedVoiceIdentifier = firstVoice.identifier
        }
    }

    private func voiceQualityLabel(for voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .enhanced:
            return "Enhanced quality"
        case .premium:
            return "Premium quality"
        default:
            return "Standard quality"
        }
    }

    private func testVoice() {
        let utterance = AVSpeechUtterance(string: "Hello! I'm your coaching assistant. How can I help you today?")
        utterance.rate = Float(viewModel.voiceRate)

        if !selectedVoiceIdentifier.isEmpty {
            utterance.voice = AVSpeechSynthesisVoice(identifier: selectedVoiceIdentifier)
        }

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}

#Preview {
    NavigationStack {
        VoiceSettingsView(
            viewModel: ProfileViewModel(appState: AppState())
        )
    }
}
