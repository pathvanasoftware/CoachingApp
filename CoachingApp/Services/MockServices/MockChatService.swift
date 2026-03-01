import Foundation

// MARK: - Mock Chat Service

final class MockChatService: ChatServiceProtocol, StreamingServiceProtocol, @unchecked Sendable {

    // MARK: - Singleton (shared instance for all ViewModels)
    
    static let shared = MockChatService()

    // MARK: - In-Memory Storage (shared across all instances via singleton)

    private static var _sessions: [String: CoachingSession] = [:]
    private static var _messages: [String: [ChatMessage]] = [:]
    private static let _lock = NSLock()
    
    // MARK: - Simulated Delay

    private let responseDelay: UInt64 = 500_000_000 // 0.5 seconds

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

        let index = incrementResponseIndex()
        let response = coachingResponses[index % coachingResponses.count]

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
        message: String,
        persona: CoachingPersonaType,
        coachingStyle: CoachingStyle? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let index = incrementResponseIndex()
        let response = coachingResponses[index % coachingResponses.count]

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
