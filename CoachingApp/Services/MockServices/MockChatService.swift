import Foundation

// MARK: - Mock Chat Service

final class MockChatService: ChatServiceProtocol, StreamingServiceProtocol, @unchecked Sendable {

    // MARK: - Singleton (shared instance for all ViewModels)
    
    static let shared = MockChatService()

    // MARK: - In-Memory Storage (shared across all instances via singleton)

    private static var _sessions: [String: CoachingSession] = [:]
    private static var _messages: [String: [ChatMessage]] = [:]
    private static var _seededUsers: Set<String> = []
    private static let _lock = NSLock()
    
    // MARK: - Simulated Delay

    private let responseDelay: UInt64 = 500_000_000 // 0.5 seconds

    func seedDemoSessionsIfNeeded(userId: String) {
        Self._lock.lock()
        defer { Self._lock.unlock() }

        guard !Self._seededUsers.contains(userId) else { return }

        let now = Date()

        let recentCompleted = CoachingSession(
            userId: userId,
            persona: .directChallenger,
            sessionType: .checkIn,
            inputMode: .text,
            startedAt: now.addingTimeInterval(-60 * 60 * 6),
            endedAt: now.addingTimeInterval(-60 * 60 * 5.5),
            summary: "Clarified priorities for a difficult stakeholder conversation.",
            durationSeconds: 1800,
            messageCount: 8
        )

        let earlierCompleted = CoachingSession(
            userId: userId,
            persona: .supportiveStrategist,
            sessionType: .deepDive,
            inputMode: .text,
            startedAt: now.addingTimeInterval(-60 * 60 * 24 * 3),
            endedAt: now.addingTimeInterval(-60 * 60 * 24 * 3 + 2100),
            summary: "Mapped burnout triggers and designed a sustainable weekly plan.",
            durationSeconds: 2100,
            messageCount: 12
        )

        let activeSession = CoachingSession(
            userId: userId,
            persona: .directChallenger,
            sessionType: .freeform,
            inputMode: .text,
            startedAt: now.addingTimeInterval(-60 * 20),
            endedAt: nil,
            summary: nil,
            durationSeconds: nil,
            messageCount: 2
        )

        Self._sessions[recentCompleted.id] = recentCompleted
        Self._messages[recentCompleted.id] = [
            ChatMessage(sessionId: recentCompleted.id, role: .user, content: "I keep delaying a tough conversation."),
            ChatMessage(sessionId: recentCompleted.id, role: .assistant, content: "Name the exact sentence you're avoiding saying."),
        ]

        Self._sessions[earlierCompleted.id] = earlierCompleted
        Self._messages[earlierCompleted.id] = [
            ChatMessage(sessionId: earlierCompleted.id, role: .user, content: "I'm exhausted by constant context switching."),
            ChatMessage(sessionId: earlierCompleted.id, role: .assistant, content: "Let's identify the two highest-friction transitions in your week."),
        ]

        Self._sessions[activeSession.id] = activeSession
        Self._messages[activeSession.id] = [
            ChatMessage(sessionId: activeSession.id, role: .assistant, content: "Welcome back. What should we focus on in this session?"),
            ChatMessage(sessionId: activeSession.id, role: .user, content: "I need help resetting priorities for this week."),
        ]

        Self._seededUsers.insert(userId)
    }

    func clearUserData(userId: String) {
        Self._lock.lock()
        defer { Self._lock.unlock() }

        let sessionIds = Self._sessions.values
            .filter { $0.userId == userId }
            .map(\.id)

        for sessionId in sessionIds {
            Self._sessions.removeValue(forKey: sessionId)
            Self._messages.removeValue(forKey: sessionId)
        }

        Self._seededUsers.remove(userId)
    }

    // MARK: - Canned Coaching Responses

    private let coachingResponses: [String] = [
        """
        That's a really important observation. Let me ask you this: when you think about the \
        situation you just described, what's the one thing you're most avoiding? Sometimes the \
        thing we dance around is exactly where the growth opportunity lives.
        """,
        """
        I hear you, and I want to acknowledge that what you're navigating isn't easy. Let's \
        break this down. What would success look like for you in this situation? Not what others \
        expect, but what would genuinely feel like a win for you?
        """,
        """
        Interesting. You mentioned that this has been a pattern. Here's what I notice: you tend \
        to take on the responsibility of managing everyone's emotions in the room. What would \
        happen if you let that go and focused purely on the strategic outcome?
        """,
        """
        Let's get specific. You said you want to improve your executive presence. Can you tell \
        me about the last meeting where you felt you didn't show up the way you wanted to? \
        What was the gap between how you showed up and how you wanted to show up?
        """,
        """
        That takes real self-awareness to recognize. Here's what I want you to consider: the \
        fact that you can see this pattern means you're already ahead of most leaders. Now \
        the question is, what's one small action you could take this week to start shifting it?
        """,
        """
        I appreciate you sharing that. It sounds like there's a tension between what you think \
        you should do and what your instinct is telling you. In my experience, when leaders \
        feel that tension, the instinct is usually pointing toward something important. What is \
        your gut telling you here?
        """,
    ]

    // MARK: - Suggestion Generation

    /// Derives natural follow-up reply suggestions directly from the coach's response text.
    /// Each coaching response asks a specific question or surfaces a specific tension —
    /// the suggestions are direct, specific reactions to that content.
    private func generateSuggestions(for response: String) -> [String] {
        let text = response.lowercased()

        // Map each canned response to replies that feel like a natural human reaction to it
        if text.contains("most avoiding") {
            return [
                "I've been avoiding having a difficult conversation",
                "Honestly, I'm avoiding making a decision",
                "I'm not sure — I haven't thought about it that way",
                "Tell me more about what you noticed"
            ]
        } else if text.contains("what would success look like") {
            return [
                "Success would mean my team respects my decisions",
                "It would feel like I'm in control again",
                "I'm not sure what success looks like right now",
                "I need help defining what I actually want"
            ]
        } else if text.contains("managing everyone's emotions") {
            return [
                "That pattern started when I became a manager",
                "I'd be afraid of what happens if I stop doing that",
                "How do I actually let go of that?",
                "I never realized I was doing that"
            ]
        } else if text.contains("executive presence") || text.contains("show up") {
            return [
                "In last week's all-hands I went blank",
                "I let someone talk over me in a key meeting",
                "I wasn't assertive when I needed to be",
                "I can think of several examples — where should I start?"
            ]
        } else if text.contains("one small action") || text.contains("this week") {
            return [
                "I could have that conversation I've been putting off",
                "I could ask for feedback from my manager",
                "I'm not sure what action would make the most difference",
                "I've tried before and it didn't stick — what's different now?"
            ]
        } else if text.contains("instinct") || text.contains("gut") {
            return [
                "My gut says I should leave this role",
                "My instinct is telling me to push back harder",
                "I'm trying to ignore my gut because it scares me",
                "I don't trust my instincts right now"
            ]
        } else {
            // Fallback: extract the coach's question and offer direct responses
            return [
                "Let me think about that...",
                "I haven't looked at it that way before",
                "Can you help me unpack that further?",
                "I'd like to explore that more"
            ]
        }
    }

    // MARK: - Response Selection

    /// Selects a coaching response based on the user's message content.
    /// This makes the mock feel more realistic by responding contextually.
    private func selectResponse(for userMessage: String) -> String {
        let text = userMessage.lowercased()

        // Match user message themes to appropriate coaching responses
        if text.contains("avoiding") || text.contains("putting off") || text.contains("procrastinating") {
            return coachingResponses[0]  // "what's the one thing you're most avoiding"
        } else if text.contains("success") || text.contains("win") || text.contains("goal") || text.contains("achieve") {
            return coachingResponses[1]  // "what would success look like"
        } else if text.contains("emotion") || text.contains("feeling") || text.contains("overwhelmed") || text.contains("team") || text.contains("manager") {
            return coachingResponses[2]  // "managing everyone's emotions"
        } else if text.contains("meeting") || text.contains("presentation") || text.contains("executive") || text.contains("presence") || text.contains("assertive") {
            return coachingResponses[3]  // "executive presence / show up"
        } else if text.contains("action") || text.contains("next step") || text.contains("this week") || text.contains("try") || text.contains("change") {
            return coachingResponses[4]  // "one small action"
        } else if text.contains("gut") || text.contains("instinct") || text.contains("intuition") || text.contains("tension") || text.contains("pulled in") {
            return coachingResponses[5]  // "instinct is telling me"
        } else {
            // Cycle through for variety when no clear match
            let index = incrementResponseIndex()
            return coachingResponses[index % coachingResponses.count]
        }
    }

    private static var _responseIndex = 0

    private func incrementResponseIndex() -> Int {
        Self._lock.lock()
        defer { Self._lock.unlock() }
        let current = Self._responseIndex
        Self._responseIndex += 1
        return current
    }

    // MARK: - ChatServiceProtocol

    func startSession(
        userId: String,
        persona: CoachingPersonaType,
        sessionType: SessionType,
        inputMode: InputMode
    ) async throws -> CoachingSession {
        try await Task.sleep(nanoseconds: responseDelay)

        let session = CoachingSession(
            userId: userId,
            persona: persona,
            sessionType: sessionType,
            inputMode: inputMode
        )

        // Add an initial greeting from the coach
        let greeting: String
        switch persona {
        case .directChallenger:
            greeting = "Good to see you. Let's not waste time. What's the most pressing challenge on your plate right now? Give me the real version, not the polished one."
        case .supportiveStrategist:
            greeting = "Welcome back. Before we dive in, how are you really doing today? Take a moment to check in with yourself. I want to make sure we focus on what matters most to you right now."
        }

        let greetingMessage = ChatMessage(
            sessionId: session.id,
            role: .assistant,
            content: greeting
        )

        Self._lock.lock()
        Self._sessions[session.id] = session
        Self._messages[session.id] = [greetingMessage]
        Self._lock.unlock()

        return session
    }

    func sendMessage(
        sessionId: String,
        content: String
    ) async throws -> ChatMessage {
        try await Task.sleep(nanoseconds: responseDelay)

        let userMessage = ChatMessage(
            sessionId: sessionId,
            role: .user,
            content: content
        )

        let response = selectResponse(for: content)

        let assistantMessage = ChatMessage(
            sessionId: sessionId,
            role: .assistant,
            content: response
        )

        Self._lock.lock()
        Self._messages[sessionId, default: []].append(userMessage)
        Self._messages[sessionId, default: []].append(assistantMessage)
        let msgCount = Self._messages[sessionId]?.count ?? 0
        if var session = Self._sessions[sessionId] {
            session.messageCount = msgCount
            Self._sessions[sessionId] = session
        }
        Self._lock.unlock()

        return assistantMessage
    }

    func endSession(sessionId: String) async throws -> CoachingSession {
        try await Task.sleep(nanoseconds: responseDelay)

        Self._lock.lock()
        guard var session = Self._sessions[sessionId] else {
            Self._lock.unlock()
            throw ChatServiceError.sessionNotFound
        }
        session.endedAt = Date()
        session.durationSeconds = Int(Date().timeIntervalSince(session.startedAt))
        session.summary = "Mock session completed with \(session.messageCount) messages exchanged."
        Self._sessions[sessionId] = session
        Self._lock.unlock()

        return session
    }

    func getSessionHistory(userId: String) async throws -> [CoachingSession] {
        try await Task.sleep(nanoseconds: responseDelay)

        Self._lock.lock()
        let result = Self._sessions.values
            .filter { $0.userId == userId }
            .sorted { $0.startedAt > $1.startedAt }
        Self._lock.unlock()
        return result
    }

    func getMessages(sessionId: String) async throws -> [ChatMessage] {
        try await Task.sleep(nanoseconds: responseDelay)
        Self._lock.lock()
        let result = Self._messages[sessionId] ?? []
        Self._lock.unlock()
        return result
    }

    // MARK: - StreamingServiceProtocol

    func streamResponse(
        sessionId: String,
        requestId: String,
        message: String,
        persona: CoachingPersonaType,
        coachingStyle: CoachingStyle? = nil
    ) -> AsyncThrowingStream<String, Error> {
        // Store the user message (only for non-greeting calls; greeting uses empty message)
        if !message.isEmpty {
            let userMessage = ChatMessage(
                sessionId: sessionId,
                role: .user,
                content: message
            )
            Self._lock.lock()
            Self._messages[sessionId, default: []].append(userMessage)
            Self._lock.unlock()
        }

        // Select response based on user's message content
        let response = message.isEmpty ? coachingResponses[0] : selectResponse(for: message)
        let suggestions = generateSuggestions(for: response)

        return AsyncThrowingStream { continuation in
            Task {
                // Split response into words and stream them with small delays
                let words = response.components(separatedBy: " ")

                for (index, word) in words.enumerated() {
                    try Task.checkCancellation()

                    let token = index == 0 ? word : " " + word
                    continuation.yield(token)

                    // Simulate variable typing speed (30-80ms per token)
                    let delay = UInt64.random(in: 30_000_000...80_000_000)
                    try await Task.sleep(nanoseconds: delay)
                }

                // Emit suggestions as a structured meta token so ChatViewModel
                // can parse them the same way it handles __META__: from the real backend
                if let data = try? JSONSerialization.data(withJSONObject: suggestions),
                   let json = String(data: data, encoding: .utf8) {
                    continuation.yield("__SUGGESTIONS__:\(json)")
                }

                // Store the complete assistant message
                let assistantMessage = ChatMessage(
                    sessionId: sessionId,
                    role: .assistant,
                    content: response
                )
                Self._lock.lock()
                Self._messages[sessionId, default: []].append(assistantMessage)
                if var session = Self._sessions[sessionId] {
                    session.messageCount = Self._messages[sessionId]?.count ?? 0
                    Self._sessions[sessionId] = session
                }
                Self._lock.unlock()

                continuation.finish()
            }
        }
    }
}
