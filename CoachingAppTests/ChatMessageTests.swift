import XCTest
@testable import CoachingApp

final class ChatMessageTests: XCTestCase {

    // MARK: - Initialization Tests

    func testMessageInitializationWithDefaults() {
        let message = ChatMessage(
            sessionId: "session1",
            role: .user,
            content: "Hello"
        )

        XCTAssertEqual(message.sessionId, "session1")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertFalse(message.isStreaming)
        XCTAssertNil(message.diagnostics)
        XCTAssertEqual(message.status, .sent)
    }

    func testMessageInitializationWithAllParameters() {
        let diagnostics = CoachingDiagnostics(
            styleUsed: "direct",
            emotionDetected: "motivated",
            goalLink: "goal1"
        )

        let message = ChatMessage(
            sessionId: "session1",
            role: .assistant,
            content: "Response",
            isStreaming: true,
            diagnostics: diagnostics,
            status: .sending
        )

        XCTAssertEqual(message.sessionId, "session1")
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.content, "Response")
        XCTAssertTrue(message.isStreaming)
        XCTAssertNotNil(message.diagnostics)
        XCTAssertEqual(message.status, .sending)
    }

    // MARK: - isFromUser Tests

    func testIsFromUserWhenUserRole() {
        let message = ChatMessage(sessionId: "s1", role: .user, content: "Test")

        XCTAssertTrue(message.isFromUser)
        XCTAssertFalse(message.isFromCoach)
    }

    func testIsFromUserWhenAssistantRole() {
        let message = ChatMessage(sessionId: "s1", role: .assistant, content: "Test")

        XCTAssertFalse(message.isFromUser)
        XCTAssertTrue(message.isFromCoach)
    }

    func testIsFromUserWhenSystemRole() {
        let message = ChatMessage(sessionId: "s1", role: .system, content: "Test")

        XCTAssertFalse(message.isFromUser)
        XCTAssertFalse(message.isFromCoach)
    }

    // MARK: - MessageStatus Tests

    func testMessageStatusRawValues() {
        XCTAssertEqual(MessageStatus.sending.rawValue, "sending")
        XCTAssertEqual(MessageStatus.sent.rawValue, "sent")
        XCTAssertEqual(MessageStatus.failed.rawValue, "failed")
    }

    // MARK: - MessageRole Tests

    func testMessageRoleRawValues() {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRole.system.rawValue, "system")
    }

    // MARK: - Identifiable Tests

    func testMessageHasUniqueId() {
        let message1 = ChatMessage(sessionId: "s1", role: .user, content: "Test 1")
        let message2 = ChatMessage(sessionId: "s1", role: .user, content: "Test 2")

        XCTAssertNotEqual(message1.id, message2.id)
    }

    // MARK: - CoachingDiagnostics Tests

    func testDiagnosticsInitialization() {
        let diagnostics = CoachingDiagnostics(
            styleUsed: "supportive",
            emotionDetected: "confident",
            goalLink: "goal123",
            goalAnchor: "anchor1",
            goalHierarchySummary: "Summary",
            progressiveSkillSummary: "Skill summary",
            outcomePredictionSummary: "Prediction",
            riskLevel: "low",
            recommendedStyleShift: "more direct",
            stageUsed: "exploration",
            stageReason: "User exploring options",
            topicShift: true,
            preStateRev: 1,
            postStateRev: 2,
            routingSignals: "signal1"
        )

        XCTAssertEqual(diagnostics.styleUsed, "supportive")
        XCTAssertEqual(diagnostics.emotionDetected, "confident")
        XCTAssertEqual(diagnostics.goalLink, "goal123")
        XCTAssertEqual(diagnostics.goalAnchor, "anchor1")
        XCTAssertEqual(diagnostics.riskLevel, "low")
        XCTAssertTrue(diagnostics.topicShift ?? false)
    }

    // MARK: - CoachingSessionSummary Tests

    func testSessionSummaryInitialization() {
        let summary = CoachingSessionSummary(
            summary: "Great progress made",
            keyInsights: ["Insight 1", "Insight 2"],
            actionItems: ["Action 1", "Action 2", "Action 3"],
            progressMade: "Completed first milestone",
            recommendedNextSteps: ["Schedule follow-up"]
        )

        XCTAssertEqual(summary.summary, "Great progress made")
        XCTAssertEqual(summary.keyInsights.count, 2)
        XCTAssertEqual(summary.actionItems.count, 3)
        XCTAssertEqual(summary.progressMade, "Completed first milestone")
        XCTAssertEqual(summary.recommendedNextSteps.count, 1)
    }
}
