import Foundation

// MARK: - Auth Service Protocol

protocol AuthServiceProtocol: Sendable {
    func signInWithEmail(email: String, password: String) async throws -> User
    func signInWithApple(identityToken: Data, nonce: String) async throws -> User
    func signOut() async throws
    func getCurrentUser() async throws -> User?
    func refreshSession() async throws
}

// MARK: - Auth Credentials

struct AuthCredentials: Codable {
    let email: String
    let password: String
}

struct AppleSignInCredentials: Codable {
    let identityToken: String
    let nonce: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User
}

struct RefreshRequest: Codable {
    let refreshToken: String
}

struct RefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
}

// MARK: - Auth Service

@Observable
final class AuthService: AuthServiceProtocol, @unchecked Sendable {

    // MARK: - Observable State

    var isAuthenticated: Bool = false
    var currentUser: User?
    var isLoading: Bool = false
    var authError: String?

    // MARK: - Dependencies

    private let apiClient: APIClient

    // MARK: - Init

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient

        // Wire up the API client to use our stored token
        self.apiClient.authTokenProvider = {
            KeychainService.loadAccessToken()
        }
    }

    // MARK: - Sign In with Email

    func signInWithEmail(email: String, password: String) async throws -> User {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        let credentials = AuthCredentials(email: email, password: password)
        let response: AuthResponse = try await apiClient.post(
            path: "/auth/v1/token?grant_type=password",
            body: credentials
        )

        try storeTokens(access: response.accessToken, refresh: response.refreshToken)

        isAuthenticated = true
        currentUser = response.user
        return response.user
    }

    // MARK: - Sign In with Apple

    func signInWithApple(identityToken: Data, nonce: String) async throws -> User {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        guard let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidToken
        }

        let credentials = AppleSignInCredentials(identityToken: tokenString, nonce: nonce)
        let response: AuthResponse = try await apiClient.post(
            path: "/auth/v1/token?grant_type=apple",
            body: credentials
        )

        try storeTokens(access: response.accessToken, refresh: response.refreshToken)

        isAuthenticated = true
        currentUser = response.user
        return response.user
    }

    // MARK: - Sign Out

    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }

        // Attempt server-side sign out (best effort)
        do {
            let emptyBody: [String: String] = [:]
            try await apiClient.post(path: "/auth/v1/logout", body: emptyBody)
        } catch {
            // Continue with local sign-out even if server call fails
        }

        clearLocalSession()
    }

    // MARK: - Get Current User

    func getCurrentUser() async throws -> User? {
        guard KeychainService.loadAccessToken() != nil else {
            return nil
        }

        do {
            let user: User = try await apiClient.get(path: "/auth/v1/user", queryItems: nil)
            currentUser = user
            isAuthenticated = true
            return user
        } catch {
            // If token is expired, try to refresh
            if case APIError.unauthorized = error {
                try await refreshSession()
                return try await getCurrentUser()
            }
            throw error
        }
    }

    // MARK: - Refresh Session

    func refreshSession() async throws {
        guard let refreshToken = KeychainService.loadRefreshToken() else {
            clearLocalSession()
            throw AuthError.noRefreshToken
        }

        let request = RefreshRequest(refreshToken: refreshToken)
        let response: RefreshResponse = try await apiClient.post(
            path: "/auth/v1/token?grant_type=refresh_token",
            body: request
        )

        try storeTokens(access: response.accessToken, refresh: response.refreshToken)
    }

    // MARK: - Session Restoration

    /// Attempt to restore a session from stored tokens on app launch.
    func restoreSession() async {
        guard KeychainService.loadAccessToken() != nil else {
            isAuthenticated = false
            return
        }

        do {
            _ = try await getCurrentUser()
        } catch {
            // If restoration fails, try refreshing
            do {
                try await refreshSession()
                _ = try await getCurrentUser()
            } catch {
                clearLocalSession()
            }
        }
    }

    // MARK: - Private Helpers

    private func storeTokens(access: String, refresh: String) throws {
        guard KeychainService.saveAccessToken(access),
              KeychainService.saveRefreshToken(refresh) else {
            throw AuthError.keychainSaveFailed
        }
    }

    private func clearLocalSession() {
        KeychainService.deleteAccessToken()
        KeychainService.deleteRefreshToken()
        isAuthenticated = false
        currentUser = nil
        authError = nil
    }
}

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case invalidToken
    case noRefreshToken
    case sessionExpired
    case keychainSaveFailed
    case appleSignInFailed(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password."
        case .invalidToken:
            return "The authentication token is invalid."
        case .noRefreshToken:
            return "No refresh token available. Please sign in again."
        case .sessionExpired:
            return "Your session has expired. Please sign in again."
        case .keychainSaveFailed:
            return "Failed to securely save authentication credentials."
        case .appleSignInFailed(let reason):
            return "Apple Sign-In failed: \(reason)"
        case .unknown(let error):
            return "Authentication error: \(error.localizedDescription)"
        }
    }
}
