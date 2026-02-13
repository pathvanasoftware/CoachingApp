//
//  ChatScreen.swift
//  AI Coaching App
//
//  Created by 刘亦菲 on 2026-02-13.
//

import SwiftUI

// MARK: - ChatScreen View
struct ChatScreen: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: ChatViewModel

    init(viewModel: ChatViewModel = ChatViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                headerView

                // Messages List
                messagesList

                // Input Area
                inputArea
            }
            .background(Color(.systemGroupedBackground))

            // Handoff Options Sheet (when user requests human coach)
            if viewModel.showHandoffOptions {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.dismissHandoffOptions()
                        }
                    }

                HandoffOptionsView(
                    hasSubscription: viewModel.hasSubscription,
                    isPresented: $viewModel.showHandoffOptions,
                    onSubscribe: {
                        viewModel.navigateToSubscription()
                    },
                    onOpenCoachChat: {
                        viewModel.openCoachChat()
                    },
                    onScheduleCall: {
                        viewModel.openCalendly()
                    }
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showHandoffOptions)
        .task {
            // Start a new session when view appears
            await viewModel.startSession(
                type: .checkIn,
                persona: appState.selectedPersona,
                inputMode: .text
            )
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI Coach")
                    .font(.headline)

                Spacer()

                if viewModel.isStreaming {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()
        }
    }

    // MARK: - Messages List
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    // Crisis Resources Alert (if applicable)
                    if viewModel.showCrisisResources {
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
                            isPresented: $viewModel.showCrisisResources
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showCrisisResources)
                    }

                    // Messages
                    ForEach(viewModel.messages) { message in
                        messageRow(for: message)
                            .id(message.id)
                    }
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Message Row with Quick Replies
    private func messageRow(for message: ChatMessage) -> some View {
        VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 8) {
            // Message Bubble
            messageBubble(for: message)

            // Quick Replies (only for AI messages)
            if !message.isFromUser && viewModel.shouldShowQuickReplies(for: message.id) {
                quickRepliesSection(for: message)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showQuickRepliesFor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Message Bubble
    private func messageBubble(for message: ChatMessage) -> some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }

            Text(message.content)
                .font(.body)
                .foregroundColor(message.isFromUser ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(message.isFromUser ? Color.blue : Color(.systemGray5))
                )
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isFromUser ? .trailing : .leading)

            if !message.isFromUser {
                Spacer()
            }
        }
    }

    // MARK: - Quick Replies Section
    private func quickRepliesSection(for message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let quickReplies = viewModel.getQuickReplies(for: message.id)
            QuickReplyView(
                suggestions: quickReplies,
                onSelect: { quickReply in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.handleQuickReply(quickReply)
                    }
                },
                onRequestHumanCoach: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.requestHumanCoach()
                    }
                }
            )
        }
    }

    // MARK: - Input Area
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // Voice Input Button
                Button(action: {
                    if viewModel.isVoiceMode {
                        viewModel.endVoiceInput()
                    } else {
                        viewModel.startVoiceInput()
                    }
                }) {
                    ZStack {
                        if viewModel.isVoiceMode {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.red, lineWidth: 2)
                                        .scaleEffect(viewModel.isVoiceMode ? 1.5 : 1.0)
                                        .opacity(viewModel.isVoiceMode ? 0 : 1)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.red, lineWidth: 2)
                                        .scaleEffect(viewModel.isVoiceMode ? 2.0 : 1.0)
                                        .opacity(viewModel.isVoiceMode ? 0 : 1)
                                )
                        } else {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 44, height: 44)
                        }

                        Image(systemName: viewModel.isVoiceMode ? "stop.fill" : "mic")
                            .font(.system(size: 20))
                            .foregroundColor(viewModel.isVoiceMode ? .red : .blue)
                    }
                }
                .accessibilityLabel(viewModel.isVoiceMode ? "Stop recording" : "Start voice input")

                // Text Input / Voice Transcription Display
                if viewModel.isVoiceMode {
                    // Show voice transcription when recording
                    Text(viewModel.currentInput.isEmpty ? "Listening..." : viewModel.currentInput)
                        .font(.body)
                        .foregroundColor(viewModel.currentInput.isEmpty ? .gray : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.red.opacity(0.05))
                        )
                } else {
                    // Regular text input field
                    TextField("Type a message...", text: $viewModel.currentInput, onCommit: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    })
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                        )
                }

                // Send Button
                if !viewModel.isVoiceMode {
                    Button(action: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                    .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isStreaming)
                    .accessibilityLabel("Send message")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Preview
#Preview {
    ChatScreen()
        .environment(AppState())
}
