import SwiftUI

struct LiveTranscriptionView: View {
    let text: String
    let isListening: Bool
    var isAIResponse: Bool = false

    @State private var showCursor: Bool = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 0) {
                    if text.isEmpty && isListening {
                        Text("Speak now...")
                            .font(AppFonts.body)
                            .foregroundStyle(AppTheme.textTertiary)
                            .italic()
                    } else {
                        Text(text)
                            .font(isAIResponse ? AppFonts.body : AppFonts.callout)
                            .foregroundStyle(
                                isAIResponse
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary
                            )
                            .multilineTextAlignment(.center)
                    }

                    if isListening && !isAIResponse {
                        Text("|")
                            .font(AppFonts.body)
                            .foregroundStyle(AppTheme.primary)
                            .opacity(showCursor ? 1 : 0)
                            .animation(
                                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                                value: showCursor
                            )
                            .onAppear {
                                showCursor = false
                            }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .id("transcriptionBottom")
            }
            .onChange(of: text) { _, _ in
                withAnimation {
                    proxy.scrollTo("transcriptionBottom", anchor: .bottom)
                }
            }
        }
        .frame(maxHeight: 120)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg)
                .fill(
                    isAIResponse
                        ? AppTheme.coachBubble
                        : AppTheme.secondaryBackground
                )
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        LiveTranscriptionView(
            text: "",
            isListening: true
        )

        LiveTranscriptionView(
            text: "I've been struggling with managing my team's expectations around the new project timeline...",
            isListening: true
        )

        LiveTranscriptionView(
            text: "That's a common challenge. Let me ask you this — have you clearly communicated the constraints that are driving the timeline?",
            isListening: false,
            isAIResponse: true
        )
    }
    .padding()
}
