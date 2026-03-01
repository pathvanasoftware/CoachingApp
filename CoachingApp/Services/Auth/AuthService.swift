import Foundation

// MARK: - Auth Service Protocol

protocol AuthServiceProtocol: Sendable {
    func signInWithEmail(email: String, password: String) async throws -> User
    func signUpWithEmail(email: String, password: String, fullName: String?) async throws -> User
    func signInWithApple(identityToken: Data, nonce: String) async throws -> User
    func signInWithGoogle() async throws -> User
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

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let data: SignUpData?
}

struct SignUpData: Codable {
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
    }
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

    // MARK: - Sign Up with Email

    func signUpWithEmail(email: String, password: String, fullName: String?) async throws -> User {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        let signUpData = fullName.map { SignUpData(fullName: $0) }
        let request = SignUpRequest(email: email, password: password, data: signUpData)

        let response: AuthResponse = try await apiClient.post(
            path: "/auth/v1/signup",
            body: request
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

    // MARK: - Sign In with Google (OAuth)

    func signInWithGoogle() async throws -> User {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        guard let supabaseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !supabaseURL.isEmpty else {
            throw AuthError.missingConfiguration
        }

        let callbackURLScheme = "com.pathvana.ascendra"
        let redirectURL = "\(callbackURLScheme)://auth-callback"

        guard var components = URLComponents(string: "\(supabaseURL)/auth/v1/authorize") else {
            throw AuthError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: redirectURL)
        ]

        guard let authURL = components.url else {
            throw AuthError.invalidURL
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackURLScheme
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: AuthError.oauthCancelled)
                }
            }
            session.presentationContextProvider = AuthenticationContextProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            _ = session.start()
        }

        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value,
              let refreshToken = queryItems.first(where: { $0.name == "refresh_token" })?.value else {
            throw AuthError.invalidOAuthResponse
        }

        try storeTokens(access: accessToken, refresh: refreshToken)

        let user: User = try await apiClient.get(path: "/auth/v1/user", queryItems: nil)
        isAuthenticated = true
        currentUser = user
        return user
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
    case googleSignInFailed(String)
    case missingConfiguration
    case invalidURL
    case oauthCancelled
    case invalidOAuthResponse
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
        case .googleSignInFailed(let reason):
            return "Google Sign-In failed: \(reason)"
        case .missingConfiguration:
            return "Authentication is not configured. Please contact support."
        case .invalidURL:
            return "Invalid authentication URL."
        case .oauthCancelled:
            return "Sign in was cancelled."
        case .invalidOAuthResponse:
            return "Invalid response from authentication provider."
        case .unknown(let error):
            return "Authentication error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Authentication Context Provider

import AuthenticationServices

private final class AuthenticationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthenticationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
