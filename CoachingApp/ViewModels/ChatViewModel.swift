//
//  ChatViewModel.swift
//  AI Coaching App
//
//  Created by 刘亦菲 on 2026-02-13.
//

import Foundation
import SwiftUI

// MARK: - ChatViewModel
@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var showQuickRepliesFor: String? = nil
    @Published var isVoiceInputActive: Bool = false
    @Published var isProcessing: Bool = false
    @Published var voiceInputError: String?

    // MARK: - Handoff State
    @Published var showCrisisResources: Bool = false
    @Published var showHandoffOptions: Bool = false
    @Published var crisisPriority: String? = nil
    @Published var hasSubscription: Bool = false

    // MARK: - Handoff Data
    private var currentHandoffResources: [CrisisResource] = []

    // MARK: - Private Properties
    private let voiceInputManager = VoiceInputManager()
    private let baseURL = "http://localhost:8000/api/v1"

    // MARK: - Send Message
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Hide quick-replies when user sends a message
        showQuickRepliesFor = nil

        // Create user message
        let userMessage = ChatMessage(
            text: text,
            isFromUser: true,
            quickReplies: nil
        )
        messages.append(userMessage)

        // Clear input
        inputText = ""

        // Call backend API
        Task {
            await processAIResponse(text: text)
        }
    }

    // MARK: - Handle Quick Reply Selection
    func handleQuickReply(_ quickReply: QuickReply) {
        // Send the quick reply as a message
        sendMessage(quickReply.text)
    }

    // MARK: - Process AI Response
    private func processAIResponse(text: String) async {
        isProcessing = true

        do {
            // Create request
            let url = URL(string: "\(baseURL)/chat")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Request body
            let requestBody = ["content": text]
            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

            // Send request
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            // Parse response
            if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messageData = jsonResponse["message"] as? [String: Any],
               let content = messageData["content"] as? String {

                // Parse handoff information
                if let handoffData = messageData["handoff"] as? [String: Any] {
                    processHandoff(handoffData)
                }

                // Parse quick replies
                var quickReplies: [QuickReply] = []
                if let quickRepliesData = messageData["quick_replies"] as? [String: Any],
                   let enabled = quickRepliesData["enabled"] as? Bool,
                   enabled,
                   let suggestions = quickRepliesData["suggestions"] as? [[String: Any]] {

                    quickReplies = suggestions.compactMap { suggestion -> QuickReply? in
                        guard let text = suggestion["text"] as? String,
                              let typeString = suggestion["type"] as? String else {
                            return nil
                        }

                        let type = QuickReplyType(rawValue: typeString) ?? .guidance
                        return QuickReply(text: text, type: type)
                    }
                }

                // Create AI message
                let aiMessage = ChatMessage(
                    text: content,
                    isFromUser: false,
                    quickReplies: quickReplies.isEmpty ? nil : quickReplies
                )

                // Show quick-replies for this AI message if available
                if !quickReplies.isEmpty {
                    showQuickRepliesFor = aiMessage.id
                }

                messages.append(aiMessage)
            }

        } catch {
            // Fallback to mock response on error
            print("API Error: \(error.localizedDescription)")

            // Create AI response with sample quick-replies
            let quickReplies = [
                QuickReply(text: "Set a goal", type: .goalOriented),
                QuickReply(text: "Need more details", type: .clarification),
                QuickReply(text: "Show me guidance", type: .guidance)
            ]

            let aiMessage = ChatMessage(
                text: "I understand. How can I help you today? (Using fallback response)",
                isFromUser: false,
                quickReplies: quickReplies
            )

            // Show quick-replies for this AI message
            showQuickRepliesFor = aiMessage.id

            messages.append(aiMessage)
        }

        isProcessing = false
    }

    // MARK: - Process Handoff from API Response
    private func processHandoff(_ handoffData: [String: Any]) {
        guard let detected = handoffData["detected"] as? Bool, detected else {
            return
        }

        if let priority = handoffData["priority"] as? String, priority == "immediate" {
            // Crisis detected - show crisis resources
            crisisPriority = priority
            currentHandoffResources = [
                CrisisResource(
                    name: "National Suicide Prevention Lifeline",
                    phone: "988",
                    textNumber: nil,
                    available: "Available 24/7"
                ),
                CrisisResource(
                    name: "Crisis Text Line",
                    phone: nil,
                    textNumber: "741741",
                    available: "Text 'HOME' to 741741"
                )
            ]
            showCrisisResources = true
        }
    }

    // MARK: - Voice Input Methods
    func startVoiceInput() {
        // Hide quick-replies when voice input starts
        showQuickRepliesFor = nil

        Task {
            do {
                try await voiceInputManager.startVoiceInput()
                await MainActor.run {
                    isVoiceInputActive = true
                    voiceInputError = nil
                }
            } catch {
                await MainActor.run {
                    voiceInputError = error.localizedDescription
                    isVoiceInputActive = false
                }
            }
        }
    }

    func endVoiceInput() {
        voiceInputManager.stopVoiceInput()
        isVoiceInputActive = false

        // If there's transcribed text, send it as a message
        let transcribedText = voiceInputManager.transcribedText
        if !transcribedText.isEmpty {
            sendMessage(transcribedText)
        }

        // Reset voice input manager
        voiceInputManager.reset()
    }

    // MARK: - Helper Methods
    func shouldShowQuickReplies(for messageId: String) -> Bool {
        return showQuickRepliesFor == messageId
    }

    func getQuickReplies(for messageId: String) -> [QuickReply]? {
        guard let message = messages.first(where: { $0.id == messageId }),
              showQuickRepliesFor == messageId else {
            return nil
        }
        return message.quickReplies
    }

    // MARK: - Handoff Methods
    func requestHumanCoach() {
        // Hide quick-replies
        showQuickRepliesFor = nil

        // Show handoff options
        showHandoffOptions = true
    }

    func openCoachChat() {
        // Navigate to coach chat
        // This would typically open a new screen or switch to a dedicated chat channel
        print("Opening coach chat...")
        showHandoffOptions = false
    }

    func openCalendly() {
        if let url = URL(string: "https://calendly.com/coaching-career") {
            UIApplication.shared.open(url)
        }
    }

    func dismissCrisisResources() {
        showCrisisResources = false
        crisisPriority = nil
        currentHandoffResources = []
    }

    func dismissHandoffOptions() {
        showHandoffOptions = false
    }

    // MARK: - Subscription Management
    func checkSubscriptionStatus() {
        // In production, this would check with the backend or app store
        // For now, we'll use a published property that can be set
        hasSubscription = UserDefaults.standard.bool(forKey: "hasSubscription")
    }

    func navigateToSubscription() {
        // Navigate to subscription screen
        print("Navigating to subscription screen...")
        showHandoffOptions = false
    }
}
