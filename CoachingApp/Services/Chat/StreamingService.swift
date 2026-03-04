import Foundation

// MARK: - Streaming Service Protocol

protocol StreamingServiceProtocol: Sendable {
    func streamResponse(
        sessionId: String,
        message: String,
        persona: CoachingPersonaType,
        coachingStyle: CoachingStyle?
    ) -> AsyncThrowingStream<String, Error>
}

// MARK: - Streaming Request

private struct StreamingRequest: Codable {
    let sessionId: String
    let message: String
    let persona: String
    let coachingStyle: String?
}

// MARK: - Streaming Service

final class StreamingService: NSObject, StreamingServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let baseURL: String
    private var authTokenProvider: (() -> String?)?

    // Use centralized API configuration from AppState
    private static var defaultBaseURL: String {
        if let saved = UserDefaults.standard.string(forKey: "com.coachingapp.apiEnvironment"),
           let env = APIEnvironment(rawValue: saved) {
            return env.chatStreamURL
        }
        #if DEBUG
        return APIEnvironment.localhost.chatStreamURL
        #else
        return APIEnvironment.production.chatStreamURL
        #endif
    }

    // MARK: - Init

    init(
        baseURL: String = StreamingService.defaultBaseURL,
        authTokenProvider: (() -> String?)? = nil
    ) {
        self.baseURL = baseURL
        self.authTokenProvider = authTokenProvider
        super.init()
    }

    // MARK: - Stream Response

    func streamResponse(
        sessionId: String,
        message: String,
        persona: CoachingPersonaType,
        coachingStyle: CoachingStyle? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await performStreamingRequest(
                        sessionId: sessionId,
                        message: message,
                        persona: persona,
                        coachingStyle: coachingStyle,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Private: Perform Streaming Request

    private func performStreamingRequest(
        sessionId: String,
        message: String,
        persona: CoachingPersonaType,
        coachingStyle: CoachingStyle?,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard let url = URL(string: baseURL) else {
            throw StreamingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        if let token = authTokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = StreamingRequest(
            sessionId: sessionId,
            message: message,
            persona: persona.rawValue,
            coachingStyle: coachingStyle?.apiValue
        )
        request.httpBody = try JSONEncoder().encode(body)

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch let urlError as URLError {
            let host = url.host?.lowercased() ?? ""
            let isLocal = host == "localhost" || host == "127.0.0.1" || host == "::1"
            if isLocal {
                throw StreamingError.localhostUnavailable(url.absoluteString)
            }
            throw urlError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StreamingError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw StreamingError.httpError(statusCode: httpResponse.statusCode)
        }

        // Parse SSE stream line-by-line in UTF-8.
        // Backend emits one `data:` JSON payload per line, so we can process directly.
        for try await rawLine in bytes.lines {
            let line = rawLine.trimmingCharacters(in: .newlines)
            if let token = parseSSELine(line) {
                if token == "[DONE]" {
                    continuation.finish()
                    return
                }
                continuation.yield(token)
            }
        }

        continuation.finish()
    }

    // MARK: - Private: SSE Parsing

    /// Parse a single SSE line and extract the data payload.
    private func parseSSELine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix(":") { return nil }
        guard trimmed.hasPrefix("data:") else { return nil }

        let data = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        guard !data.isEmpty else { return nil }

        if data == "[DONE]" {
            return data
        }

        if let jsonData = data.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            if let token = json["token"] as? String {
                return token
            }
            if let meta = json["meta"],
               let metaData = try? JSONSerialization.data(withJSONObject: meta),
               let metaString = String(data: metaData, encoding: .utf8) {
                return "__META__:\(metaString)"
            }
        }

        return data
    }
}

// MARK: - Streaming Error

enum StreamingError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case connectionLost
    case decodingFailed
    case cancelled
    case localhostUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The streaming URL is invalid."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .httpError(let statusCode):
            return "Streaming failed with HTTP status \(statusCode)."
        case .connectionLost:
            return "The streaming connection was lost."
        case .decodingFailed:
            return "Failed to decode streamed data."
        case .cancelled:
            return "The streaming request was cancelled."
        case .localhostUnavailable(let url):
            return "Cannot reach local backend at \(url). Switch API Environment to Production in app settings."
        }
    }
}
