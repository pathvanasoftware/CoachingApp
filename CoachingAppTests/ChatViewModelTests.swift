import XCTest
@testable import CoachingApp

final class ChatViewModelTests: XCTestCase {

    var sut: ChatViewModel!
    var mockChatService: MockChatService!
    var mockStreamingService: MockChatService!

    override func setUp() {
        super.setUp()
        mockChatService = MockChatService()
        mockStreamingService = MockChatService()
        sut = ChatViewModel(
            chatService: mockChatService,
            streamingService: mockStreamingService
        )
    }

    override func tearDown() {
        sut = nil
        mockChatService = nil
        mockStreamingService = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertNil(sut.currentSession)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isStreaming)
    }

    // MARK: - Session Tests

    func testStartSessionSuccess() async {
        await sut.startSession(
            type: .freeform,
            persona: .directChallenger,
            userId: "test-user"
        )

        XCTAssertNotNil(sut.currentSession)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.messages.isEmpty)
    }

    func testStartSessionSetsCorrectPersona() async {
        await sut.startSession(
            type: .freeform,
            persona: .supportiveStrategist,
            userId: "test-user"
        )

        XCTAssertEqual(sut.currentSession?.persona, .supportiveStrategist)
    }

    // MARK: - Timer Tests

    func testTimerStartsWhenSessionStarts() async throws {
        await sut.startSession(
            type: .freeform,
            persona: .directChallenger,
            userId: "test-user"
        )

        let initialElapsed = sut.elapsedSeconds
        try await Task.sleep(nanoseconds: 1_100_000_000)
        XCTAssertGreaterThan(sut.elapsedSeconds, initialElapsed)
    }

    func testTimerStopsWhenSessionEnds() async throws {
        await sut.startSession(
            type: .freeform,
            persona: .directChallenger,
            userId: "test-user"
        )

        let elapsedAtEnd = sut.elapsedSeconds
        await sut.endSession()

        try await Task.sleep(nanoseconds: 1_100_000_000)
        XCTAssertEqual(sut.elapsedSeconds, elapsedAtEnd)
    }

    // MARK: - Message Tests

    func testSendMessageAddsUserMessage() async {
        await sut.startSession(
            type: .freeform,
            persona: .directChallenger,
            userId: "test-user"
        )

        let initialCount = sut.messages.count
        sut.currentInput = "Test message"
        await sut.sendMessage()

        XCTAssertGreaterThan(sut.messages.count, initialCount)
    }

    // MARK: - Error Handling Tests

    func testErrorMessageClearedOnNewSession() async {
        sut.errorMessage = "Previous error"

        await sut.startSession(
            type: .freeform,
            persona: .directChallenger,
            userId: "test-user"
        )

        XCTAssertNil(sut.errorMessage)
    }
}
