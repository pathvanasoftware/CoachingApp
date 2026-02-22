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
    @State private var hasRunRegressionFlow = false

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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.showCrisisResources)
        .onChange(of: viewModel.selectedCoachingStyle) { _, newValue in
            appState.selectedCoachingStyle = newValue
        }
        .sheet(isPresented: $viewModel.showCrisisResources) {
            CrisisResourceView(
                resources: crisisResources,
                isPresented: $viewModel.showCrisisResources
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .task {
            viewModel.selectedCoachingStyle = appState.selectedCoachingStyle

            // Start a new session when view appears
            await viewModel.startSession(
                type: .checkIn,
                persona: appState.selectedPersona,
                inputMode: .text
            )

            // Optional automation for regression screenshots
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--regression-chat") && !hasRunRegressionFlow {
                hasRunRegressionFlow = true
                await runRegressionFlowIfNeeded()
            }
        }
    }

    private var crisisResources: [CrisisResourceModel] {
        [
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
        ]
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI Coach")
                    .font(.headline)

                Spacer()

                Menu {
                    Picker("Coaching Style", selection: $viewModel.selectedCoachingStyle) {
                        ForEach(CoachingStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }

                    Divider()

                    Button {
                        exportSession()
                    } label: {
                        Label("Export Session", systemImage: "square.and.arrow.up")
                    }
                    .disabled(viewModel.messages.isEmpty)

                    Button(appState.showDebugDiagnostics ? "Hide Debug Diagnostics" : "Show Debug Diagnostics") {
                        appState.showDebugDiagnostics.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selectedCoachingStyle.displayName)
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
                }

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

            if appState.showDebugDiagnostics, !message.isFromUser, let d = message.diagnostics {
                diagnosticsChips(style: d.styleUsed, emotion: d.emotionDetected, goal: d.goalLink)
                goalArchitectureDetails(d)
            }

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

    private func diagnosticsChips(style: String, emotion: String, goal: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("Style: \(style)", tint: styleTint(style))
                chip("Emotion: \(emotion)", tint: emotionTint(emotion))
                chip("Goal: \(goal)", tint: goalTint(goal))
            }
            .padding(.vertical, 2)
        }
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 0.8))
            .clipShape(Capsule())
    }

    private func styleTint(_ style: String) -> Color {
        switch style.lowercased() {
        case "directive": return .orange
        case "facilitative": return .indigo
        case "supportive": return .mint
        case "strategic": return .blue
        default: return .secondary
        }
    }

    private func emotionTint(_ emotion: String) -> Color {
        switch emotion.lowercased() {
        case "distressed": return .red
        case "low_confidence", "uncertain": return .orange
        case "motivated": return .green
        default: return .secondary
        }
    }

    private func goalTint(_ goal: String) -> Color {
        switch goal.lowercased() {
        case "career_advancement": return .purple
        case "leadership_effectiveness": return .blue
        case "execution_excellence": return .teal
        case "wellbeing_first": return .red
        default: return .secondary
        }
    }

    private func goalArchitectureDetails(_ d: CoachingDiagnostics) -> some View {
        let hasDetails = [
            d.goalAnchor,
            d.goalHierarchySummary,
            d.progressiveSkillSummary,
            d.outcomePredictionSummary,
            d.riskLevel,
            d.recommendedStyleShift,
        ]
        .contains { ($0 ?? "").isEmpty == false }

        return Group {
            if hasDetails {
                DisclosureGroup("Goal Insights") {
                    VStack(alignment: .leading, spacing: 4) {
                        if let anchor = d.goalAnchor, !anchor.isEmpty {
                            detailLine("Anchor", anchor)
                        }
                        if let h = d.goalHierarchySummary, !h.isEmpty {
                            detailLine("Hierarchy", h)
                        }
                        if let p = d.progressiveSkillSummary, !p.isEmpty {
                            detailLine("Skill", p)
                        }
                        if let o = d.outcomePredictionSummary, !o.isEmpty {
                            detailLine("Prediction", o)
                        }
                        if let risk = d.riskLevel, !risk.isEmpty {
                            detailLine("Risk", risk)
                        }
                        if let shift = d.recommendedStyleShift, !shift.isEmpty {
                            detailLine("Style Shift", shift)
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }

    private func detailLine(_ label: String, _ text: String) -> some View {
        Text("\(label): \(text)")
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(3)
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    @MainActor
    private func runRegressionFlowIfNeeded() async {
        let args = ProcessInfo.processInfo.arguments

        // Crisis branch
        if args.contains("--regression-crisis") {
            try? await Task.sleep(for: .milliseconds(600))
            viewModel.currentInput = "I feel hopeless and want to kill myself"
            await viewModel.sendMessage()
            try? await Task.sleep(for: .milliseconds(700))
            viewModel.requestHumanCoach()
            return
        }

        // Default branch: quick reply + handoff options
        try? await Task.sleep(for: .milliseconds(600))
        viewModel.currentInput = "I need help planning my next career step"
        await viewModel.sendMessage()

        try? await Task.sleep(for: .milliseconds(600))
        if let last = viewModel.messages.last {
            let suggestions = viewModel.getQuickReplies(for: last.id)
            if let first = suggestions.first {
                viewModel.handleQuickReply(first)
            }
        }

        try? await Task.sleep(for: .milliseconds(900))
        viewModel.requestHumanCoach()
    }

    // MARK: - Export Session

    @State private var showShareSheet = false
    @State private var exportURL: URL?

    private func exportSession() {
        guard let session = viewModel.currentSession, !viewModel.messages.isEmpty else { return }

        let url = SessionExportService.shareSession(
            session: session,
            messages: viewModel.messages,
            as: .markdown
        )

        exportURL = url
        showShareSheet = true
    }
}

// MARK: - Preview
#Preview {
    ChatScreen()
        .environment(AppState())
}
import Foundation
import SwiftUI

// MARK: - Session Export Service

struct SessionExportService {

    // MARK: - Export as Text

    static func exportAsText(session: CoachingSession, messages: [ChatMessage]) -> String {
        var text = """
        Coaching Session Export
        ========================
        Date: \(session.startedAt.formatted(date: .complete, time: .shortened))
        Type: \(session.sessionType.displayName)
        Duration: \(session.formattedDuration)
        Persona: \(session.persona.displayName)

        ========================

        """

        for message in messages {
            let timestamp = message.timestamp.formatted(date: .omitted, time: .shortened)
            let role = message.role == .user ? "👤 You" : "🤖 Coach"

            text += "[\(timestamp)] \(role):\n"
            text += "\(message.content)\n"

            if let diagnostics = message.diagnostics, message.role == .assistant {
                text += "\n---\n"
                text += "Style: \(diagnostics.styleUsed)\n"
                text += "Emotion: \(diagnostics.emotionDetected)\n"
                text += "Goal: \(diagnostics.goalLink)\n"
                if let risk = diagnostics.riskLevel {
                    text += "Risk Level: \(risk)\n"
                }
                text += "---\n"
            }

            text += "\n"
        }

        text += "\n---\n"
        text += "Exported from CoachingApp on \(Date().formatted(date: .complete, time: .shortened))\n"

        return text
    }

    // MARK: - Export as Markdown

    static func exportAsMarkdown(session: CoachingSession, messages: [ChatMessage]) -> String {
        var markdown = """
        # Coaching Session

        **Date:** \(session.startedAt.formatted(date: .complete, time: .shortened))
        **Type:** \(session.sessionType.displayName)
        **Duration:** \(session.formattedDuration)
        **Persona:** \(session.persona.displayName)

        ---

        """

        for message in messages {
            let timestamp = message.timestamp.formatted(date: .omitted, time: .shortened)
            let role = message.role == .user ? "👤 **You**" : "🤖 **Coach**"

            markdown += "### \(role) - \(timestamp)\n\n"
            markdown += "\(message.content)\n\n"

            if let diagnostics = message.diagnostics, message.role == .assistant {
                markdown += "<details>\n"
                markdown += "<summary>📊 Coaching Insights</summary>\n\n"
                markdown += "- **Style:** \(diagnostics.styleUsed)\n"
                markdown += "- **Emotion:** \(diagnostics.emotionDetected)\n"
                markdown += "- **Goal:** \(diagnostics.goalLink)\n"
                if let risk = diagnostics.riskLevel {
                    markdown += "- **Risk Level:** \(risk)\n"
                }
                if let shift = diagnostics.recommendedStyleShift {
                    markdown += "- **Style Shift:** \(shift)\n"
                }
                markdown += "\n</details>\n\n"
            }
        }

        markdown += "---\n\n"
        markdown += "*Exported from CoachingApp on \(Date().formatted(date: .complete, time: .shortened))*\n"

        return markdown
    }

    // MARK: - Share Sheet

    static func shareSession(session: CoachingSession, messages: [ChatMessage], as format: ExportFormat = .text) -> URL {
        let content: String
        let fileExtension: String

        switch format {
        case .text:
            content = exportAsText(session: session, messages: messages)
            fileExtension = "txt"
        case .markdown:
            content = exportAsMarkdown(session: session, messages: messages)
            fileExtension = "md"
        }

        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "coaching_session_\(session.id).\(fileExtension)"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try? content.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }
}

// MARK: - Export Format

enum ExportFormat {
    case text
    case markdown
}
import SwiftUI
import UIKit

// MARK: - Share Sheet (UIViewControllerRepresentable)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
