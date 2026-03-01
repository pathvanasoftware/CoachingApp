//
//  QuickReplyView.swift
//  AI Coaching App
//
//  Created by 刘亦菲 on 2026-02-13.
//

import SwiftUI

// MARK: - QuickReplyView Component
struct QuickReplyView: View {
    let suggestions: [QuickReply]
    let onSelect: (QuickReply) -> Void
    var onRequestHumanCoach: (() -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    Button(action: { onSelect(suggestion) }) {
                        Text(suggestion.text)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGray5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(suggestion.text)
                    .accessibilityHint("Tap to send this reply")
                    .accessibilityAddTraits(.isButton)
                }

                if let onRequestHumanCoach {
                    Button(action: onRequestHumanCoach) {
                        Label("Talk to Career Coach", systemImage: "person.circle")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Talk to Career Coach")
                    .accessibilityHint("Connect with a human coach")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Preview
#Preview {
    QuickReplyView(
        suggestions: [
            QuickReply(id: "1", text: "Set a goal", type: .goalOriented),
            QuickReply(id: "2", text: "I need clarification", type: .clarification),
            QuickReply(id: "3", text: "Show me guidance", type: .guidance),
            QuickReply(id: "4", text: "Take action", type: .action),
            QuickReply(id: "5", text: "Reflect on this", type: .reflection)
        ],
        onSelect: { suggestion in
            print("Selected: \(suggestion.text)")
        },
        onRequestHumanCoach: {
            print("Talk to Career Coach tapped")
        }
    )
}
