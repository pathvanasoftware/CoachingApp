import Foundation

/// Holds shared real service instances for the app.
/// Injected into the SwiftUI environment at the root so any view or view model
/// can access the live chat and streaming services without going through mocks.
@Observable
final class ServiceContainer {

    var chatService: ChatServiceProtocol
    var streamingService: StreamingServiceProtocol
    var goalService: GoalServiceProtocol

    private var realChatService: ChatService
    private var realStreamingService: StreamingService
    private var realGoalService: GoalService
    private let mockService = MockChatService.shared
    private let mockGoalService = MockGoalService()

    init() {
        let chat = ChatService()
        let streaming = StreamingService(
            baseURL: APIEnvironment.production.chatStreamURL,
            authTokenProvider: { KeychainService.loadAccessToken() }
        )
        let goals = GoalService()
        self.realChatService = chat
        self.realStreamingService = streaming
        self.realGoalService = goals
        self.chatService = chat
        self.streamingService = streaming
        self.goalService = goals
    }

    func configure(useMockServices: Bool, apiEnvironment: APIEnvironment) {
        realChatService = ChatService(apiClient: APIClient(baseURL: apiEnvironment.baseURL))
        realStreamingService = StreamingService(
            baseURL: apiEnvironment.chatStreamURL,
            authTokenProvider: { KeychainService.loadAccessToken() }
        )
        realGoalService = GoalService(apiClient: APIClient(baseURL: apiEnvironment.baseURL))

        if useMockServices {
            chatService = mockService
            streamingService = mockService
            goalService = mockGoalService
        } else {
            chatService = realChatService
            streamingService = realStreamingService
            goalService = realGoalService
        }
    }
}
