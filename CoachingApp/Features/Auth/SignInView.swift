import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AppState.self) private var appState
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
                        viewModel.signInWithApple(result: result, appState: appState)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                }

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

                // MARK: - Email Form
                VStack(spacing: AppTheme.Spacing.md) {
                    if viewModel.isSignUp {
                        // Full name field (sign up only)
                        TextField("Full Name", text: $viewModel.fullName)
                            .textFieldStyle(.plain)
                            .textContentType(.name)
                            .padding(AppTheme.Spacing.md)
                            .background(AppTheme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
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

                    // Confirm password field (sign up only)
                    if viewModel.isSignUp {
                        SecureField("Confirm Password", text: $viewModel.confirmPassword)
                            .textFieldStyle(.plain)
                            .textContentType(.newPassword)
                            .padding(AppTheme.Spacing.md)
                            .background(AppTheme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                    }

                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(AppFonts.footnote)
                            .foregroundStyle(AppTheme.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Submit button
                    Button {
                        Task {
                            if viewModel.isSignUp {
                                await viewModel.signUpWithEmail(appState: appState)
                            } else {
                                await viewModel.signInWithEmail(appState: appState)
                            }
                        }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(viewModel.isSignUp ? "Create Account" : "Sign In")
                            }
                        }
                        .primaryButtonStyle()
                    }
                    .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                    .opacity(viewModel.email.isEmpty || viewModel.password.isEmpty ? 0.6 : 1.0)
                }

                // MARK: - Toggle Sign Up / Sign In
                Button {
                    viewModel.toggleMode()
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.isSignUp ? "Already have an account?" : "Don't have an account?")
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(viewModel.isSignUp ? "Sign In" : "Sign Up")
                            .foregroundStyle(AppTheme.primary)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }

                Spacer()
                    .frame(height: AppTheme.Spacing.xl)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .background(AppTheme.background)
    }
}

#Preview {
    SignInView()
        .environment(AppState())
}
