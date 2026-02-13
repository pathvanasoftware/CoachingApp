//
//  CrisisResourceView.swift
//  AI Coaching App
//
//  Created by 刘亦菲 on 2026-02-13.
//

import SwiftUI

// MARK: - Crisis Resource View
struct CrisisResourceView: View {
    let resources: [CrisisResourceModel]
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with dismiss button
            HStack {
                Text("📞 24/7 Crisis Support")
                    .font(.headline)
                    .foregroundColor(.red)

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 20))
                }
                .accessibilityLabel("Dismiss")
            }

            Divider()
                .background(Color.red.opacity(0.3))

            // Crisis resources list
            ForEach(Array(resources.enumerated()), id: \.offset) { index, resource in
                resourceRow(for: resource)

                if index < resources.count - 1 {
                    Divider()
                        .background(Color.red.opacity(0.2))
                }
            }
        }
        .padding()
        .background(Color(.systemRed).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Resource Row
    private func resourceRow(for resource: CrisisResourceModel) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Resource info
            VStack(alignment: .leading, spacing: 4) {
                Text(resource.name)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(resource.available)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                if let phone = resource.phone {
                    Button(action: { makeCall(to: phone) }) {
                        Label("Call", systemImage: "phone.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(16)
                    }
                }

                if let textNumber = resource.textNumber {
                    Button(action: { sendText(to: textNumber) }) {
                        Label("Text", systemImage: "message.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white)
                            .cornerRadius(16)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Phone Call
    private func makeCall(to phoneNumber: String) {
        if let url = URL(string: "tel://\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Send Text Message
    private func sendText(to phoneNumber: String) {
        if let url = URL(string: "sms://\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview
#Preview {
    CrisisResourceView(
        resources: [
            CrisisResourceModel(
                name: "National Suicide Prevention Lifeline",
                phone: "988",
                textNumber: nil,
                available: "Available 24/7"
            ),
            CrisisResourceModel(
                name: "Crisis Text Line",
                phone: nil,
                textNumber: "741741",
                available: "Text 'HOME' to 741741"
            )
        ],
        isPresented: .constant(true)
    )
    .padding()
}
