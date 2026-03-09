import Foundation

/// Holds shared real service instances for the app.
/// Injected into the SwiftUI environment at the root so any view or view model
/// can access the live chat and streaming services without going through mocks.
@Observable
final class ServiceContainer {

    var chatService: ChatServiceProtocol
    var streamingService: StreamingServiceProtocol

    private var realChatService: ChatService
    private var realStreamingService: StreamingService
    private let mockService = MockChatService.shared

    init() {
        let chat = ChatService()
        let streaming = StreamingService(
            baseURL: APIEnvironment.production.chatStreamURL,
            authTokenProvider: { KeychainService.loadAccessToken() }
        )
        self.realChatService = chat
        self.realStreamingService = streaming
        self.chatService = chat
        self.streamingService = streaming
    }

    func configure(useMockServices: Bool, apiEnvironment: APIEnvironment) {
        realChatService = ChatService(apiClient: APIClient(baseURL: apiEnvironment.baseURL))
        realStreamingService = StreamingService(
            baseURL: apiEnvironment.chatStreamURL,
            authTokenProvider: { KeychainService.loadAccessToken() }
        )

        if useMockServices {
            chatService = mockService
            streamingService = mockService
        } else {
            chatService = realChatService
            streamingService = realStreamingService
        }
    }
}
