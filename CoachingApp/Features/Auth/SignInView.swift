import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AppState.self) private var appState
    @Environment(AuthService.self) private var authService
    @Environment(ServiceContainer.self) private var services
    @State private var viewModel = AuthViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.xl) {
                Spacer()
                    .frame(height: AppTheme.Spacing.xl)

                // MARK: - App Logo & Title
                VStack(spacing: AppTheme.Spacing.md) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22))

                    Text("Ascendra")
                        .font(AppFonts.largeTitle)
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("AI-powered executive coaching\nthat meets you where you are.")
                        .font(AppFonts.body)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // MARK: - Social Sign In Buttons
                VStack(spacing: AppTheme.Spacing.sm) {
                    // Google Sign In
                    Button {
                        Task {
                            appState.useMockServices = false
                            services.configure(useMockServices: false, apiEnvironment: appState.apiEnvironment)
                            await viewModel.signInWithGoogle(appState: appState)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .medium))
                            Text("Continue with Google")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .foregroundStyle(.black)

                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        appState.useMockServices = false
                        services.configure(useMockServices: false, apiEnvironment: appState.apiEnvironment)
                        viewModel.signInWithApple(result: result, appState: appState)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))

                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AppFonts.footnote)
                        .foregroundStyle(AppTheme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
                    .frame(height: AppTheme.Spacing.xl)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .background(AppTheme.background)
        .onAppear {
            viewModel.authService = authService
        }
    }
}

#Preview {
    SignInView()
        .environment(AppState())
}
