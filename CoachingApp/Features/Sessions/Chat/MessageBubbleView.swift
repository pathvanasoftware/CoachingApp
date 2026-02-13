import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage
    let persona: CoachingPersonaType

    var body: some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
            if message.isFromUser {
                Spacer(minLength: 60)
            }

            if message.isFromCoach {
                PersonaAvatar(persona: persona, size: 32)
                    .offset(y: -4)
            }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: AppTheme.Spacing.xxs) {
                // Message bubble
                HStack {
                    if message.isFromUser { Spacer(minLength: 0) }

                    Text(message.content.isEmpty && message.isStreaming ? " " : message.content)
                        .font(AppFonts.body)
                        .foregroundStyle(message.isFromUser ? .white : AppTheme.textPrimary)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm + AppTheme.Spacing.xxs)
                        .background(bubbleBackground)
                        .clipShape(bubbleShape)
                        .overlay(alignment: .bottomTrailing) {
                            if message.isStreaming {
                                streamingCursor
                            }
                        }

                    if !message.isFromUser { Spacer(minLength: 0) }
                }

                // Timestamp
                Text(message.timestamp.timeDisplay)
                    .font(AppFonts.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                    .padding(.horizontal, AppTheme.Spacing.xs)
            }

            if message.isFromCoach {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }

    // MARK: - Bubble Styling

    private var bubbleBackground: Color {
        message.isFromUser ? AppTheme.userBubble : AppTheme.coachBubble
    }

    private var bubbleShape: UnevenRoundedRectangle {
        let large = AppTheme.CornerRadius.lg
        let small = AppTheme.CornerRadius.xs

        if message.isFromUser {
            // User bubble: rounded on all corners except bottom-right (tail side)
            return UnevenRoundedRectangle(
                topLeadingRadius: large,
                bottomLeadingRadius: large,
                bottomTrailingRadius: small,
                topTrailingRadius: large
            )
        } else {
            // Coach bubble: rounded on all corners except bottom-left (tail side)
            return UnevenRoundedRectangle(
                topLeadingRadius: large,
                bottomLeadingRadius: small,
                bottomTrailingRadius: large,
                topTrailingRadius: large
            )
        }
    }

    // MARK: - Streaming Cursor

    private var streamingCursor: some View {
        BlinkingCursor()
            .padding(.trailing, AppTheme.Spacing.sm)
            .padding(.bottom, AppTheme.Spacing.sm)
    }
}

// MARK: - Blinking Cursor

private struct BlinkingCursor: View {
    @State private var isVisible = true

    var body: some View {
        Rectangle()
            .fill(AppTheme.textSecondary)
            .frame(width: 2, height: 16)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
    }
}

// MARK: - Preview

#Preview("Message Bubbles") {
    VStack(spacing: 12) {
        MessageBubbleView(
            message: ChatMessage(
                sessionId: "preview",
                role: .assistant,
                content: "Welcome back. What's on your mind today?"
            ),
            persona: .directChallenger
        )

        MessageBubbleView(
            message: ChatMessage(
                sessionId: "preview",
                role: .user,
                content: "I need help preparing for a difficult conversation with my VP."
            ),
            persona: .directChallenger
        )

        MessageBubbleView(
            message: ChatMessage(
                sessionId: "preview",
                role: .assistant,
                content: "Let's get into it. What makes this conversation difficult -- is it the content or the person?",
                isStreaming: true
            ),
            persona: .directChallenger
        )
    }
    .padding()
}
