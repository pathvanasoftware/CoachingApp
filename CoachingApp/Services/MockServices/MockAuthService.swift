import Foundation

// MARK: - Mock Auth Service

@Observable
final class MockAuthService: AuthServiceProtocol, @unchecked Sendable {

    // MARK: - Observable State

    var isAuthenticated: Bool = false
    var currentUser: User?
    var isLoading: Bool = false

    // MARK: - Configuration

    /// Simulated network delay in nanoseconds (default: 0.8 seconds).
    var simulatedDelay: UInt64 = 800_000_000

    /// Whether sign-in should simulate a failure.
    var shouldFailSignIn: Bool = false

    // MARK: - Mock User

    private let mockUser = User(
        id: "mock-user-001",
        email: "alex.morgan@example.com",
        fullName: "Alex Morgan",
        organizationId: "mock-org-001",
        seatTier: .professional,
        preferredPersona: .directChallenger,
        preferredInputMode: .text,
        hasCompletedOnboarding: true,
        createdAt: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
        updatedAt: Date()
    )

    // MARK: - AuthServiceProtocol

    func signInWithEmail(email: String, password: String) async throws -> User {
        isLoading = true
        defer { isLoading = false }

        try await Task.sleep(nanoseconds: simulatedDelay)

        if shouldFailSignIn {
            throw AuthError.invalidCredentials
        }

        // Create a user with the provided email
        let user = User(
            id: mockUser.id,
            email: email,
            fullName: mockUser.fullName,
            organizationId: mockUser.organizationId,
            seatTier: mockUser.seatTier,
            preferredPersona: mockUser.preferredPersona,
            preferredInputMode: mockUser.preferredInputMode,
            hasCompletedOnboarding: mockUser.hasCompletedOnboarding,
            createdAt: mockUser.createdAt,
            updatedAt: Date()
        )

        isAuthenticated = true
        currentUser = user
        return user
    }

    func signInWithApple(identityToken: Data, nonce: String) async throws -> User {
        isLoading = true
        defer { isLoading = false }

        try await Task.sleep(nanoseconds: simulatedDelay)

        if shouldFailSignIn {
            throw AuthError.appleSignInFailed("Mock Apple Sign-In failure")
        }

        isAuthenticated = true
        currentUser = mockUser
        return mockUser
    }

    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }

        try await Task.sleep(nanoseconds: simulatedDelay / 2)

        isAuthenticated = false
        currentUser = nil
    }

    func getCurrentUser() async throws -> User? {
        try await Task.sleep(nanoseconds: simulatedDelay / 2)

        return currentUser
    }

    func refreshSession() async throws {
        try await Task.sleep(nanoseconds: simulatedDelay / 2)

        // Mock refresh always succeeds if user is authenticated
        guard isAuthenticated else {
            throw AuthError.sessionExpired
        }
    }
}
