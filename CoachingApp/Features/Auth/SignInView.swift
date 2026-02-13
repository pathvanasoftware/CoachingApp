import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AuthViewModel()

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            // MARK: - App Logo & Title
            VStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.primary)

                Text("CoachingApp")
                    .font(AppFonts.largeTitle)
                    .foregroundStyle(AppTheme.textPrimary)

                Text("AI-powered executive coaching\nthat meets you where you are.")
                    .font(AppFonts.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // MARK: - Sign In Form
            VStack(spacing: AppTheme.Spacing.md) {
                // Sign in with Apple
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    viewModel.signInWithApple(result: result, appState: appState)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))

                // Divider
                HStack {
                    Rectangle()
                        .fill(AppTheme.textTertiary.opacity(0.3))
                        .frame(height: 1)
                    Text("or")
                        .font(AppFonts.footnote)
                        .foregroundStyle(AppTheme.textTertiary)
                    Rectangle()
                        .fill(AppTheme.textTertiary.opacity(0.3))
                        .frame(height: 1)
                }

                // Email field
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(.plain)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))

                // Password field
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.plain)
                    .textContentType(.password)
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))

                // Error message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AppFonts.footnote)
                        .foregroundStyle(AppTheme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Sign In button
                Button {
                    Task {
                        await viewModel.signInWithEmail(appState: appState)
                    }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .primaryButtonStyle()
                }
                .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                .opacity(viewModel.email.isEmpty || viewModel.password.isEmpty ? 0.6 : 1.0)
            }

            Spacer()
                .frame(height: AppTheme.Spacing.xl)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .background(AppTheme.background)
    }
}

#Preview {
    SignInView()
        .environment(AppState())
}
