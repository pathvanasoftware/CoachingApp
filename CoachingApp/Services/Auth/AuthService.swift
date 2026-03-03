import Foundation
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif

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

struct SignUpCredentials: Codable {
    let email: String
    let password: String
    let fullName: String?
    
    enum CodingKeys: String, CodingKey {
        case email, password
        case fullName = "full_name"
    }
}

struct AppleSignInCredentials: Codable {
    let identityToken: String
    let nonce: String
    
    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case nonce
    }
}

struct GoogleSignInRequest: Codable {
    let code: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct RefreshRequest: Codable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct RefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct GoogleOAuthResponse: Codable {
    let authUrl: String
    
    enum CodingKeys: String, CodingKey {
        case authUrl = "auth_url"
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
    
    // MARK: - Session Storage (must retain ASWebAuthenticationSession)
    
    private var webAuthSession: ASWebAuthenticationSession?

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
            path: "/auth/login",
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

        let credentials = SignUpCredentials(email: email, password: password, fullName: fullName)
        let response: AuthResponse = try await apiClient.post(
            path: "/auth/register",
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
            path: "/auth/apple",
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

        // Get OAuth URL from backend.
        // Backend callback then redirects to app scheme with auth tokens.
        let redirectUri = googleRedirectURI()
        print("[GoogleAuth] Getting OAuth URL with redirect_uri: \(redirectUri)")
        
        let authURLString = try await fetchGoogleAuthURL(redirectUri: redirectUri)
        print("[GoogleAuth] Got auth URL: \(authURLString)")

        guard let authURL = URL(string: authURLString) else {
            print("[GoogleAuth] ERROR: Invalid URL")
            throw AuthError.invalidURL
        }

        // Open OAuth flow
        print("[GoogleAuth] Starting ASWebAuthenticationSession...")
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.pathvana.ascendra"
            ) { [weak self] callbackURL, error in
                self?.webAuthSession = nil
                if let error {
                    print("[GoogleAuth] ASWebAuthenticationSession error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    print("[GoogleAuth] Got callback URL: \(callbackURL.absoluteString)")
                    continuation.resume(returning: callbackURL)
                } else {
                    print("[GoogleAuth] ERROR: No callback URL and no error")
                    continuation.resume(throwing: AuthError.oauthCancelled)
                }
            }
            session.presentationContextProvider = AuthenticationContextProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            let started = session.start()
            print("[GoogleAuth] Session started: \(started)")
            if !started {
                self.webAuthSession = nil
                continuation.resume(throwing: AuthError.googleSignInFailed("Unable to start authentication session"))
            }
        }

        // Extract tokens from callback (backend returns access_token & refresh_token directly)
        print("[GoogleAuth] Parsing callback URL components...")
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("[GoogleAuth] ERROR: Could not parse URL components")
            throw AuthError.invalidOAuthResponse
        }
        
        print("[GoogleAuth] Query items: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" })")
        
        guard let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value,
              let refreshToken = queryItems.first(where: { $0.name == "refresh_token" })?.value else {
            print("[GoogleAuth] ERROR: Missing access_token or refresh_token in callback")
            throw AuthError.invalidOAuthResponse
        }
        
        print("[GoogleAuth] Got tokens, fetching user...")

        // Store tokens and fetch user
        try storeTokens(access: accessToken, refresh: refreshToken)
        let user = try await fetchCurrentUserFlexible()

        print("[GoogleAuth] Success! User: \(user.email)")
        isAuthenticated = true
        currentUser = user
        return user
    }

    private func googleRedirectURI() -> String {
        if let saved = UserDefaults.standard.string(forKey: "com.coachingapp.apiEnvironment"),
           let env = APIEnvironment(rawValue: saved) {
            switch env {
            case .localhost:
                return "http://localhost:8000/api/auth/google/callback"
            case .production:
                return "https://coachingapp-backend-production.up.railway.app/api/auth/google/callback"
            case .staging:
                return "https://staging-coachingapp.railway.app/api/auth/google/callback"
            }
        }
        return "https://coachingapp-backend-production.up.railway.app/api/auth/google/callback"
    }

    private func fetchGoogleAuthURL(redirectUri: String) async throws -> String {
        do {
            let oauthResponse: GoogleOAuthResponse = try await apiClient.get(
                path: "/auth/google/url",
                queryItems: [URLQueryItem(name: "redirect_uri", value: redirectUri)]
            )
            return oauthResponse.authUrl
        } catch APIError.decodingError(let decodeError) {
            let (data, response) = try await apiClient.dataRequest(
                method: .get,
                path: "/auth/google/url?redirect_uri=\(redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectUri)"
            )
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
            }
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let authURL = obj["auth_url"] as? String ?? obj["authUrl"] as? String {
                return authURL
            }
            throw AuthError.googleSignInFailed("Invalid OAuth URL response: \(decodeError.localizedDescription)")
        }
    }

    private func fetchCurrentUserFlexible() async throws -> User {
        do {
            let user: User = try await apiClient.get(path: "/auth/me", queryItems: nil)
            return user
        } catch APIError.decodingError(_) {
            let (data, response) = try await apiClient.dataRequest(method: .get, path: "/auth/me")
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
            }
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = obj["id"] as? String,
                  let email = obj["email"] as? String else {
                throw AuthError.googleSignInFailed("Invalid user payload from /auth/me")
            }

            let seatRaw = (obj["seat_tier"] as? String) ?? (obj["seatTier"] as? String) ?? "starter"
            let seatTier = SeatTier(rawValue: seatRaw) ?? .starter

            let personaRaw = (obj["preferred_persona"] as? String) ?? (obj["preferredPersona"] as? String) ?? "direct_challenger"
            let normalizedPersona = personaRaw
                .replacingOccurrences(of: "directChallenger", with: "direct_challenger")
                .replacingOccurrences(of: "supportiveStrategist", with: "supportive_strategist")
            let preferredPersona = CoachingPersonaType(rawValue: normalizedPersona) ?? .directChallenger

            let inputRaw = (obj["preferred_input_mode"] as? String) ?? (obj["preferredInputMode"] as? String) ?? "text"
            let preferredInputMode = InputMode(rawValue: inputRaw) ?? .text

            return User(
                id: id,
                email: email,
                fullName: (obj["full_name"] as? String) ?? (obj["fullName"] as? String),
                organizationId: (obj["organization_id"] as? String) ?? (obj["organizationId"] as? String),
                seatTier: seatTier,
                preferredPersona: preferredPersona,
                preferredInputMode: preferredInputMode,
                hasCompletedOnboarding: (obj["has_completed_onboarding"] as? Bool) ?? (obj["hasCompletedOnboarding"] as? Bool) ?? false,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }

    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }

        // Attempt server-side sign out (best effort)
        do {
            let emptyBody: [String: String] = [:]
            try await apiClient.post(path: "/auth/logout", body: emptyBody)
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
            let user: User = try await apiClient.get(path: "/auth/me", queryItems: nil)
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
            path: "/auth/refresh",
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

private final class AuthenticationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthenticationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
#if canImport(UIKit)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
#endif
        return ASPresentationAnchor()
    }
}
