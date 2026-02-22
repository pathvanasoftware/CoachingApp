import Foundation

// MARK: - API Error

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidRequest
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case encodingError(Error)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError
    case networkError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .invalidRequest:
            return "The request could not be constructed."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .httpError(let statusCode, _):
            return "HTTP error with status code \(statusCode)."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .unauthorized:
            return "Authentication required. Please sign in again."
        case .forbidden:
            return "You do not have permission to access this resource."
        case .notFound:
            return "The requested resource was not found."
        case .rateLimited:
            return "Too many requests. Please try again shortly."
        case .serverError:
            return "A server error occurred. Please try again later."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// MARK: - API Client Protocol

protocol APIClientProtocol: Sendable {
    func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]?
    ) async throws -> T

    func post<T: Decodable, U: Encodable>(
        path: String,
        body: U
    ) async throws -> T

    func put<T: Decodable, U: Encodable>(
        path: String,
        body: U
    ) async throws -> T

    func delete(
        path: String
    ) async throws
}

// MARK: - API Client

final class APIClient: APIClientProtocol, @unchecked Sendable {
    private let session: URLSession
    private let baseURL: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Closure that provides the current auth token, if available.
    /// Set this after authentication to automatically inject the token into requests.
    var authTokenProvider: (@Sendable () -> String?)?

    init(
        baseURL: String = APIClient.defaultBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO 8601 with fractional seconds first
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            // Fall back to ISO 8601 without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(dateString)"
            )
        }

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Configuration

    // Use centralized API configuration from AppState
    private static var defaultBaseURL: String {
        // Access UserDefaults directly to avoid dependency on AppState
        if let saved = UserDefaults.standard.string(forKey: "com.coachingapp.apiEnvironment"),
           let env = APIEnvironment(rawValue: saved) {
            return env.baseURL
        }
        #if DEBUG
        return APIEnvironment.localhost.baseURL
        #else
        return APIEnvironment.production.baseURL
        #endif
    }

    // MARK: - Public Methods

    func get<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let request = try buildRequest(method: .get, path: path, queryItems: queryItems)
        return try await execute(request)
    }

    func post<T: Decodable, U: Encodable>(
        path: String,
        body: U
    ) async throws -> T {
        var request = try buildRequest(method: .post, path: path)
        request.httpBody = try encodeBody(body)
        return try await execute(request)
    }

    func put<T: Decodable, U: Encodable>(
        path: String,
        body: U
    ) async throws -> T {
        var request = try buildRequest(method: .put, path: path)
        request.httpBody = try encodeBody(body)
        return try await execute(request)
    }

    func delete(path: String) async throws {
        let request = try buildRequest(method: .delete, path: path)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    /// Convenience overload for POST that returns Void.
    func post<U: Encodable>(
        path: String,
        body: U
    ) async throws {
        var request = try buildRequest(method: .post, path: path)
        request.httpBody = try encodeBody(body)
        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    // MARK: - Raw Data Access (for streaming / custom handling)

    func dataRequest(
        method: HTTPMethod,
        path: String,
        body: Data? = nil
    ) async throws -> (Data, URLResponse) {
        var request = try buildRequest(method: method, path: path)
        request.httpBody = body
        return try await session.data(for: request)
    }

    // MARK: - Private Helpers

    private func buildRequest(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        if let queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Supabase requires apikey header
        // TODO: Replace with your actual anon key
        request.setValue(
            "your-supabase-anon-key",
            forHTTPHeaderField: "apikey"
        )

        // Inject auth token if available
        if let token = authTokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func encodeBody<U: Encodable>(_ body: U) throws -> Data {
        do {
            return try encoder.encode(body)
        } catch {
            throw APIError.encodingError(error)
        }
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        try validateResponse(response, data: data)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }
}
