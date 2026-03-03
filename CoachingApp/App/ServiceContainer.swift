import Foundation

/// Holds shared real service instances for the app.
/// Injected into the SwiftUI environment at the root so any view or view model
/// can access the live chat and streaming services without going through mocks.
@Observable
final class ServiceContainer {

    var chatService: ChatServiceProtocol
    var streamingService: StreamingServiceProtocol

    private let realChatService: ChatService
    private let realStreamingService: StreamingService
    private let mockService = MockChatService.shared

    init() {
        let apiClient = APIClient()
        apiClient.authTokenProvider = { KeychainService.loadAccessToken() }
        self.realChatService = ChatService(apiClient: apiClient)
        self.realStreamingService = StreamingService(
            authTokenProvider: { KeychainService.loadAccessToken() }
        )
        self.chatService = realChatService
        self.streamingService = realStreamingService
    }

    func configure(useMockServices: Bool) {
        if useMockServices {
            chatService = mockService
            streamingService = mockService
        } else {
            chatService = realChatService
            streamingService = realStreamingService
        }
    }
}
