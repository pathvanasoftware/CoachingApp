import Foundation

/// Holds shared real service instances for the app.
/// Injected into the SwiftUI environment at the root so any view or view model
/// can access the live chat and streaming services without going through mocks.
@Observable
final class ServiceContainer {

    var chatService: ChatServiceProtocol
    var streamingService: StreamingServiceProtocol

    private let realStreamingService: StreamingService
    private let mockService = MockChatService.shared

    init() {
        let apiClient = APIClient()
        apiClient.authTokenProvider = { KeychainService.loadAccessToken() }
        self.realStreamingService = StreamingService(
            authTokenProvider: { KeychainService.loadAccessToken() }
        )
        // Use local session lifecycle service by default; streaming decides mock/real AI.
        self.chatService = mockService
        self.streamingService = realStreamingService
    }

    func configure(useMockServices: Bool) {
        if useMockServices {
            chatService = mockService
            streamingService = mockService
        } else {
            // Backend currently exposes chat endpoints, not session CRUD endpoints.
            // Keep session lifecycle local while routing AI responses to real backend stream.
            chatService = mockService
            streamingService = realStreamingService
        }
    }
}
