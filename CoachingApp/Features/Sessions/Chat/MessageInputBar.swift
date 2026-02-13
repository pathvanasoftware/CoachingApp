import SwiftUI

struct MessageInputBar: View {
    @Binding var text: String
    var isEnabled: Bool = true
    var onSend: () -> Void
    var onVoiceTap: (() -> Void)?

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: AppTheme.Spacing.sm) {
                // Voice mode button
                if let onVoiceTap {
                    Button(action: onVoiceTap) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                    .disabled(!isEnabled)
                    .opacity(isEnabled ? 1.0 : 0.4)
                }

                // Text field
                HStack(alignment: .bottom, spacing: AppTheme.Spacing.xs) {
                    TextField("Type a message...", text: $text, axis: .vertical)
                        .font(AppFonts.body)
                        .lineLimit(1...6)
                        .focused($isTextFieldFocused)
                        .disabled(!isEnabled)
                        .onSubmit {
                            if canSend {
                                onSend()
                            }
                        }
                        .submitLabel(.send)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.xl)
                        .strokeBorder(
                            isTextFieldFocused
                                ? AppTheme.primary.opacity(0.5)
                                : Color.clear,
                            lineWidth: 1
                        )
                )

                // Send button
                Button {
                    onSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? AppTheme.primary : AppTheme.textTertiary)
                        .symbolEffect(.bounce, value: canSend)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(AppTheme.background)
        }
    }

    // MARK: - Helpers

    private var canSend: Bool {
        isEnabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Preview

#Preview("Empty") {
    VStack {
        Spacer()
        MessageInputBar(
            text: .constant(""),
            onSend: {},
            onVoiceTap: {}
        )
    }
}

#Preview("With Text") {
    VStack {
        Spacer()
        MessageInputBar(
            text: .constant("I need help with my leadership approach"),
            onSend: {},
            onVoiceTap: {}
        )
    }
}

#Preview("Disabled") {
    VStack {
        Spacer()
        MessageInputBar(
            text: .constant(""),
            isEnabled: false,
            onSend: {},
            onVoiceTap: {}
        )
    }
}
