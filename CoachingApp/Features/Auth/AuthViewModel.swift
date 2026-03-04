import Foundation
import AuthenticationServices

@Observable
final class AuthViewModel {
    var email: String = ""
    var password: String = ""
    var fullName: String = ""
    var confirmPassword: String = ""
    var isSignUp: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    private var currentAppleNonce: String?

    var authService: AuthServiceProtocol

    init(authService: AuthServiceProtocol = MockAuthService()) {
        self.authService = authService
    }

    @MainActor
    func signInWithEmail(appState: AppState) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signInWithEmail(email: email, password: password)
            appState.useMockServices = false
            appState.switchAPIEnvironment(APIEnvironment.production)
            appState.signIn(userId: user.id, email: user.email, name: user.fullName ?? "")
        } catch {
            errorMessage = "Sign in failed. Please check your credentials and try again."
        }

        isLoading = false
    }

    @MainActor
    func signUpWithEmail(appState: AppState) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }

        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signUpWithEmail(
                email: email,
                password: password,
                fullName: fullName.isEmpty ? nil : fullName
            )
            appState.useMockServices = false
            appState.switchAPIEnvironment(APIEnvironment.production)
            appState.signIn(userId: user.id, email: user.email, name: user.fullName ?? "")
        } catch {
            errorMessage = "Sign up failed. Please try again."
        }

        isLoading = false
    }

    @MainActor
    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = nonce
    }

    @MainActor
    func signInWithApple(result: Result<ASAuthorization, any Error>, appState: AppState) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken else {
                errorMessage = "Unable to process Apple Sign In credentials."
                return
            }

            guard let nonce = currentAppleNonce, !nonce.isEmpty else {
                errorMessage = "Apple Sign In security check failed. Please try again."
                return
            }

            isLoading = true
            errorMessage = nil

            Task {
                defer { self.currentAppleNonce = nil }
                do {
                    let user = try await authService.signInWithApple(
                        identityToken: identityToken,
                        nonce: nonce
                    )
                    appState.useMockServices = false
                    appState.switchAPIEnvironment(APIEnvironment.production)
                    appState.signIn(userId: user.id, email: user.email, name: user.fullName ?? "")
                } catch let error as AuthError {
                    errorMessage = error.errorDescription
                } catch {
                    errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
                }
                isLoading = false
            }

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                errorMessage = nil
            } else {
                errorMessage = "Apple Sign In was cancelled or failed."
            }
        }
    }

    @MainActor
    func signInWithGoogle(appState: AppState) async {
        isLoading = true
        errorMessage = nil

        do {
            let user = try await authService.signInWithGoogle()
            appState.useMockServices = false
            appState.switchAPIEnvironment(APIEnvironment.production)
            appState.signIn(userId: user.id, email: user.email, name: user.fullName ?? "")
        } catch let error as AuthError {
            if case .oauthCancelled = error {
                // User cancelled - don't show error
            } else {
                errorMessage = error.errorDescription
            }
        } catch {
            let nsError = error as NSError
            let isCancelled = nsError.domain == ASWebAuthenticationSessionError.errorDomain
                && nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
            if isCancelled {
                // User cancelled - don't show error
            } else {
                errorMessage = "Google Sign In failed: \(error.localizedDescription)"
            }
        }

        isLoading = false
    }

    func toggleMode() {
        isSignUp.toggle()
        errorMessage = nil
        password = ""
        confirmPassword = ""
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)

        for _ in 0..<length {
            result.append(charset[Int.random(in: 0..<charset.count)])
        }
        return result
    }
}
