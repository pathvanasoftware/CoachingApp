import SwiftUI

struct VoiceModeView: View {
    @State private var viewModel: VoiceViewModel
    @Environment(\.dismiss) private var dismiss

    var onSwitchToText: (() -> Void)?

    init(
        persona: CoachingPersonaType = .directChallenger,
        onSwitchToText: (() -> Void)? = nil
    ) {
        self._viewModel = State(initialValue: VoiceViewModel(persona: persona))
        self.onSwitchToText = onSwitchToText
    }

    var body: some View {
        ZStack {
            // Background
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar

                Spacer()

                // Center content
                centerContent

                Spacer()

                // Transcription area
                transcriptionArea

                // Controls
                controlBar
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.lg)
        }
        .task {
            await viewModel.beginSession()
        }
        .alert(
            "Error",
            isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            },
            message: {
                Text(viewModel.errorMessage ?? "")
            }
        )
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                viewModel.persona.accentColor.opacity(0.08),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                Task {
                    await viewModel.endSession()
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.secondaryBackground)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: AppTheme.Spacing.xxs) {
                Text(viewModel.persona.displayName)
                    .font(AppFonts.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Text(viewModel.voiceState.statusText)
                    .font(AppFonts.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }

            Spacer()

            // Pause / Resume
            Button {
                if viewModel.voiceState == .paused {
                    viewModel.resumeSession()
                } else {
                    viewModel.pauseSession()
                }
            } label: {
                Image(systemName: viewModel.voiceState == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.secondaryBackground)
                    .clipShape(Circle())
            }
        }
        .padding(.top, AppTheme.Spacing.md)
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            // Persona avatar with pulsing ring
            ZStack {
                // Pulsing ring when active
                if viewModel.voiceState == .speaking || viewModel.voiceState == .listening {
                    Circle()
                        .stroke(
                            viewModel.persona.accentColor.opacity(0.3),
                            lineWidth: 3
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(viewModel.voiceState == .speaking ? 1.15 : 1.05)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: viewModel.voiceState
                        )

                    Circle()
                        .stroke(
                            viewModel.persona.accentColor.opacity(0.15),
                            lineWidth: 2
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(viewModel.voiceState == .speaking ? 1.2 : 1.08)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: viewModel.voiceState
                        )
                }

                PersonaAvatar(persona: viewModel.persona, size: 120)
                    .shadow(
                        color: viewModel.persona.accentColor.opacity(0.3),
                        radius: viewModel.voiceState == .idle ? 0 : 20
                    )
                    .animation(.easeInOut(duration: 0.5), value: viewModel.voiceState)
            }

            // Waveform
            WaveformView(
                isActive: viewModel.voiceState == .listening || viewModel.voiceState == .speaking,
                amplitude: viewModel.amplitude
            )
            .frame(height: 44)

            // State-specific content
            stateContent
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.voiceState {
        case .idle:
            Text("Tap the microphone to speak")
                .font(AppFonts.subheadline)
                .foregroundStyle(AppTheme.textTertiary)

        case .listening:
            Text("I'm listening...")
                .font(AppFonts.subheadline)
                .foregroundStyle(viewModel.persona.accentColor)

        case .processing:
            HStack(spacing: AppTheme.Spacing.sm) {
                ProgressView()
                    .tint(viewModel.persona.accentColor)
                Text("Processing your response...")
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }

        case .speaking:
            Text("Coach is responding...")
                .font(AppFonts.subheadline)
                .foregroundStyle(viewModel.persona.accentColor)

        case .paused:
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.textTertiary)
                Text("Session paused")
                    .font(AppFonts.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }

    // MARK: - Transcription Area

    private var transcriptionArea: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if !viewModel.currentResponse.isEmpty && viewModel.voiceState == .speaking {
                LiveTranscriptionView(
                    text: viewModel.currentResponse,
                    isListening: false,
                    isAIResponse: true
                )
            }

            if viewModel.voiceState == .listening || !viewModel.transcribedText.isEmpty {
                LiveTranscriptionView(
                    text: viewModel.transcribedText,
                    isListening: viewModel.voiceState == .listening
                )
            }
        }
        .padding(.bottom, AppTheme.Spacing.md)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            // Main mic button
            HStack(spacing: AppTheme.Spacing.xxl) {
                // Switch to text
                Button {
                    Task {
                        await viewModel.endSession()
                        onSwitchToText?()
                    }
                } label: {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 20))
                            .frame(width: 48, height: 48)
                            .background(AppTheme.secondaryBackground)
                            .clipShape(Circle())

                        Text("Text")
                            .font(AppFonts.caption2)
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }

                // Microphone button
                Button {
                    handleMicTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(micButtonColor)
                            .frame(width: 72, height: 72)
                            .shadow(color: micButtonColor.opacity(0.4), radius: 8, y: 4)

                        Image(systemName: micButtonIcon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(viewModel.voiceState == .processing)

                // End session
                Button {
                    Task {
                        await viewModel.endSession()
                        dismiss()
                    }
                } label: {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 20))
                            .frame(width: 48, height: 48)
                            .background(AppTheme.error.opacity(0.15))
                            .clipShape(Circle())

                        Text("End")
                            .font(AppFonts.caption2)
                    }
                    .foregroundStyle(AppTheme.error)
                }
            }
        }
    }

    // MARK: - Mic Button Helpers

    private var micButtonColor: Color {
        switch viewModel.voiceState {
        case .idle:
            return viewModel.persona.accentColor
        case .listening:
            return AppTheme.error
        case .processing:
            return AppTheme.textTertiary
        case .speaking:
            return viewModel.persona.accentColor.opacity(0.5)
        case .paused:
            return AppTheme.warning
        }
    }

    private var micButtonIcon: String {
        switch viewModel.voiceState {
        case .idle:
            return "mic.fill"
        case .listening:
            return "stop.fill"
        case .processing:
            return "ellipsis"
        case .speaking:
            return "speaker.wave.2.fill"
        case .paused:
            return "mic.fill"
        }
    }

    private func handleMicTap() {
        switch viewModel.voiceState {
        case .idle:
            viewModel.startListening()
        case .listening:
            viewModel.stopListening()
        case .speaking:
            viewModel.textToSpeechStop()
        case .paused:
            viewModel.resumeSession()
            viewModel.startListening()
        case .processing:
            break
        }
    }
}

// MARK: - ViewModel extension for view access

extension VoiceViewModel {
    func textToSpeechStop() {
        voiceState = .idle
    }
}

// MARK: - Preview

#Preview {
    VoiceModeView(persona: .directChallenger)
}
