import Foundation
import AuthenticationServices

@Observable
final class AuthViewModel {
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    private let authService: AuthServiceProtocol

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
            appState.signIn(userId: user.id, email: user.email, name: user.fullName)
        } catch {
            errorMessage = "Sign in failed. Please check your credentials and try again."
        }

        isLoading = false
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

            isLoading = true
            errorMessage = nil

            Task {
                do {
                    let user = try await authService.signInWithApple(
                        identityToken: identityToken,
                        nonce: ""
                    )
                    appState.signIn(userId: user.id, email: user.email, name: user.fullName)
                } catch {
                    errorMessage = "Apple Sign In failed. Please try again."
                }
                isLoading = false
            }

        case .failure:
            errorMessage = "Apple Sign In was cancelled or failed."
        }
    }
}
