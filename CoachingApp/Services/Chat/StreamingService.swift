import Foundation

// MARK: - Streaming Service Protocol

protocol StreamingServiceProtocol: Sendable {
    func streamResponse(
        sessionId: String,
        message: String,
        persona: CoachingPersonaType
    ) -> AsyncThrowingStream<String, Error>
}

// MARK: - Streaming Request

private struct StreamingRequest: Codable {
    let sessionId: String
    let message: String
    let persona: String
}

// MARK: - Streaming Service

final class StreamingService: NSObject, StreamingServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let baseURL: String
    private var authTokenProvider: (() -> String?)?

    // Local backend for development
    private static let defaultBaseURL = "http://localhost:8000/api/v1"

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
        persona: CoachingPersonaType
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await performStreamingRequest(
                        sessionId: sessionId,
                        message: message,
                        persona: persona,
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
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        guard let url = URL(string: "\(baseURL)/chat-stream") else {
            throw StreamingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        // Inject auth token
        if let token = authTokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // TODO: Replace with your actual anon key
        request.setValue("your-supabase-anon-key", forHTTPHeaderField: "apikey")

        let body = StreamingRequest(
            sessionId: sessionId,
            message: message,
            persona: persona.rawValue
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StreamingError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw StreamingError.httpError(statusCode: httpResponse.statusCode)
        }

        // Parse SSE (Server-Sent Events) stream
        var buffer = ""

        for try await byte in bytes {
            let character = Character(UnicodeScalar(byte))
            buffer.append(character)

            // SSE events are separated by double newlines
            while let eventRange = buffer.range(of: "\n\n") {
                let eventString = String(buffer[buffer.startIndex..<eventRange.lowerBound])
                buffer.removeSubrange(buffer.startIndex...eventRange.upperBound)

                if let token = parseSSEEvent(eventString) {
                    if token == "[DONE]" {
                        continuation.finish()
                        return
                    }
                    continuation.yield(token)
                }
            }
        }

        // Process any remaining buffer
        if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let token = parseSSEEvent(buffer) {
                if token != "[DONE]" {
                    continuation.yield(token)
                }
            }
        }

        continuation.finish()
    }

    // MARK: - Private: SSE Parsing

    /// Parse a Server-Sent Event block and extract the data payload.
    ///
    /// SSE format:
    /// ```
    /// event: message
    /// data: {"token": "Hello"}
    /// ```
    private func parseSSEEvent(_ event: String) -> String? {
        let lines = event.components(separatedBy: "\n")

        for line in lines {
            // Skip comments (lines starting with ":")
            if line.hasPrefix(":") {
                continue
            }

            // Extract data field
            if line.hasPrefix("data: ") {
                let data = String(line.dropFirst(6))

                // Try to parse as JSON with a "token" field
                if let jsonData = data.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let token = json["token"] as? String {
                    return token
                }

                // If not JSON, return raw data (could be "[DONE]" or plain text)
                return data
            }

            if line.hasPrefix("data:") {
                let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if !data.isEmpty {
                    return data
                }
            }
        }

        return nil
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
        }
    }
}
