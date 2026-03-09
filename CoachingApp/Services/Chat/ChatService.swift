import Foundation

// MARK: - Chat Service Protocol

protocol ChatServiceProtocol: Sendable {
    func startSession(
        userId: String,
        persona: CoachingPersonaType,
        sessionType: SessionType,
        inputMode: InputMode
    ) async throws -> CoachingSession

    func sendMessage(
        sessionId: String,
        content: String
    ) async throws -> ChatMessage

    func endSession(
        sessionId: String
    ) async throws -> CoachingSession

    func getSessionHistory(
        userId: String
    ) async throws -> [CoachingSession]

    func getMessages(
        sessionId: String
    ) async throws -> [ChatMessage]

    func deleteSession(
        sessionId: String
    ) async throws
}

// MARK: - Request / Response DTOs

private struct StartSessionRequest: Codable {
    let userId: String
    let persona: String
    let sessionType: String
    let inputMode: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case persona
        case sessionType = "session_type"
        case inputMode = "input_mode"
    }
}

private struct SendMessageRequest: Codable {
    let sessionId: String
    let content: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case content
        case role
    }
}

private struct EndSessionRequest: Codable {
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
    }
}

// MARK: - Chat Service

final class ChatService: ChatServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let apiClient: APIClient

    // MARK: - Init

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
        self.apiClient.authTokenProvider = {
            KeychainService.loadAccessToken()
        }
    }

    // MARK: - Start Session

    func startSession(
        userId: String,
        persona: CoachingPersonaType,
        sessionType: SessionType,
        inputMode: InputMode
    ) async throws -> CoachingSession {
        let request = StartSessionRequest(
            userId: userId,
            persona: persona.rawValue,
            sessionType: sessionType.rawValue,
            inputMode: inputMode.rawValue
        )

        let session: CoachingSession = try await apiClient.post(
            path: "/sessions",
            body: request
        )

        return session
    }

    // MARK: - Send Message

    func sendMessage(
        sessionId: String,
        content: String
    ) async throws -> ChatMessage {
        let request = SendMessageRequest(
            sessionId: sessionId,
            content: content,
            role: MessageRole.user.rawValue
        )

        let response: ChatMessage = try await apiClient.post(
            path: "/sessions/\(sessionId)/messages",
            body: request
        )

        return response
    }

    // MARK: - End Session

    func endSession(sessionId: String) async throws -> CoachingSession {
        let request = EndSessionRequest(sessionId: sessionId)

        let session: CoachingSession = try await apiClient.post(
            path: "/sessions/\(sessionId)/end",
            body: request
        )

        return session
    }

    // MARK: - Get Session History

    func getSessionHistory(userId: String) async throws -> [CoachingSession] {
        let sessions: [CoachingSession] = try await apiClient.get(
            path: "/sessions",
            queryItems: nil
        )

        return sessions
    }

    // MARK: - Get Messages

    func getMessages(sessionId: String) async throws -> [ChatMessage] {
        let messages: [ChatMessage] = try await apiClient.get(
            path: "/sessions/\(sessionId)/messages",
            queryItems: nil
        )

        return messages
    }

    // MARK: - Delete Session

    func deleteSession(sessionId: String) async throws {
        try await apiClient.delete(path: "/sessions/\(sessionId)")
    }
}

// MARK: - Chat Service Error

enum ChatServiceError: Error, LocalizedError {
    case sessionNotFound
    case sessionAlreadyEnded
    case messageSendFailed
    case invalidSessionState

    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "The coaching session was not found."
        case .sessionAlreadyEnded:
            return "This session has already ended."
        case .messageSendFailed:
            return "Failed to send the message. Please try again."
        case .invalidSessionState:
            return "The session is in an invalid state."
        }
    }
}
