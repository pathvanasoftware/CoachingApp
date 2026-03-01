import Foundation

/// Holds shared real service instances for the app.
/// Injected into the SwiftUI environment at the root so any view or view model
/// can access the live chat and streaming services without going through mocks.
@Observable
final class ServiceContainer {

    let chatService: ChatService
    let streamingService: StreamingService

    init() {
        let apiClient = APIClient()
        apiClient.authTokenProvider = { KeychainService.loadAccessToken() }
        self.chatService = ChatService(apiClient: apiClient)
        self.streamingService = StreamingService(
            authTokenProvider: { KeychainService.loadAccessToken() }
        )
    }
}
