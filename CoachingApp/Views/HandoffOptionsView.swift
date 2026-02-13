//
//  HandoffOptionsView.swift
//  AI Coaching App
//
//  Created by 刘亦菲 on 2026-02-13.
//

import SwiftUI

// MARK: - Subscription Prompt View
struct SubscriptionPrompt: View {
    let onSubscribe: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(.systemYellow).opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: "crown.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.yellow)
            }

            // Text
            VStack(spacing: 8) {
                Text("Premium Required")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Human coaching requires an active subscription")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Subscribe button
            Button(action: onSubscribe) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                    Text("Subscribe Now")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }

            // Features list
            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "person.circle", text: "1-on-1 coaching sessions")
                featureRow(icon: "calendar", text: "Flexible scheduling")
                featureRow(icon: "message.circle", text: "Direct chat access")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Handoff Options View
struct HandoffOptionsView: View {
    @State var hasSubscription: Bool = false
    @Binding var isPresented: Bool
    let onSubscribe: () -> Void
    let onOpenCoachChat: () -> Void
    let onScheduleCall: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect with a Career Coach")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("Get personalized guidance from an expert")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                }
                .accessibilityLabel("Dismiss")
            }

            Divider()

            // Content based on subscription status
            if !hasSubscription {
                SubscriptionPrompt(onSubscribe: onSubscribe)
            } else {
                coachingOptions
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    // MARK: - Coaching Options (for subscribed users)
    private var coachingOptions: some View {
        VStack(spacing: 12) {
            // In-app chat button
            Button(action: onOpenCoachChat) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 50, height: 50)

                        Image(systemName: "message.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chat with Coach")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Start a conversation instantly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())

            // Scheduling button
            Button(action: onScheduleCall) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 50, height: 50)

                        Image(systemName: "calendar")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(0.2), lineWidth: 2)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schedule a Call")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("Book a time that works for you")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())

            // Note
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("Your coach typically responds within 24 hours")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Preview
#Preview("No Subscription") {
    HandoffOptionsView(
        hasSubscription: false,
        isPresented: .constant(true),
        onSubscribe: { print("Subscribe tapped") },
        onOpenCoachChat: { print("Open coach chat tapped") },
        onScheduleCall: { print("Schedule call tapped") }
    )
    .padding()
}

#Preview("With Subscription") {
    HandoffOptionsView(
        hasSubscription: true,
        isPresented: .constant(true),
        onSubscribe: { print("Subscribe tapped") },
        onOpenCoachChat: { print("Open coach chat tapped") },
        onScheduleCall: { print("Schedule call tapped") }
    )
    .padding()
}
