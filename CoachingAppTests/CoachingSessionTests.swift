import XCTest
@testable import CoachingApp

final class CoachingSessionTests: XCTestCase {

    // MARK: - Initialization Tests

    func testSessionInitializationWithDefaults() {
        let session = CoachingSession(userId: "user1")

        XCTAssertEqual(session.userId, "user1")
        XCTAssertEqual(session.persona, .directChallenger)
        XCTAssertEqual(session.sessionType, .checkIn)
        XCTAssertEqual(session.inputMode, .text)
        XCTAssertNil(session.endedAt)
        XCTAssertNil(session.summary)
        XCTAssertNil(session.durationSeconds)
        XCTAssertEqual(session.messageCount, 0)
        XCTAssertTrue(session.goalIds.isEmpty)
    }

    func testSessionInitializationWithAllParameters() {
        let startedAt = Date().addingTimeInterval(-3600) // 1 hour ago
        let endedAt = Date()
        let summary = CoachingSessionSummary(
            summary: "Great session",
            keyInsights: ["Insight 1"],
            actionItems: ["Action 1"],
            progressMade: "Good progress",
            recommendedNextSteps: ["Next step 1"]
        )

        let session = CoachingSession(
            userId: "user1",
            persona: .supportiveStrategist,
            sessionType: .deepDive,
            inputMode: .voice,
            startedAt: startedAt,
            endedAt: endedAt,
            summary: "Session summary",
            sessionSummary: summary,
            durationSeconds: 3600,
            messageCount: 10,
            goalIds: ["goal1", "goal2"]
        )

        XCTAssertEqual(session.userId, "user1")
        XCTAssertEqual(session.persona, .supportiveStrategist)
        XCTAssertEqual(session.sessionType, .deepDive)
        XCTAssertEqual(session.inputMode, .voice)
        XCTAssertEqual(session.startedAt, startedAt)
        XCTAssertEqual(session.endedAt, endedAt)
        XCTAssertEqual(session.summary, "Session summary")
        XCTAssertEqual(session.durationSeconds, 3600)
        XCTAssertEqual(session.messageCount, 10)
        XCTAssertEqual(session.goalIds.count, 2)
    }

    // MARK: - isActive Tests

    func testIsActiveWhenNoEndedAt() {
        let session = CoachingSession(userId: "user1")

        XCTAssertTrue(session.isActive)
    }

    func testIsActiveWhenEndedAtSet() {
        let session = CoachingSession(
            userId: "user1",
            endedAt: Date()
        )

        XCTAssertFalse(session.isActive)
    }

    // MARK: - formattedDuration Tests

    func testFormattedDurationWhenNil() {
        let session = CoachingSession(userId: "user1")

        XCTAssertEqual(session.formattedDuration, "--:--")
    }

    func testFormattedDurationLessThanMinute() {
        let session = CoachingSession(userId: "user1", durationSeconds: 45)

        XCTAssertEqual(session.formattedDuration, "0:45")
    }

    func testFormattedDurationExactlyOneMinute() {
        let session = CoachingSession(userId: "user1", durationSeconds: 60)

        XCTAssertEqual(session.formattedDuration, "1:00")
    }

    func testFormattedDurationMinutesAndSeconds() {
        let session = CoachingSession(userId: "user1", durationSeconds: 125) // 2:05

        XCTAssertEqual(session.formattedDuration, "2:05")
    }

    func testFormattedDurationLargeValue() {
        let session = CoachingSession(userId: "user1", durationSeconds: 3725) // 62:05

        XCTAssertEqual(session.formattedDuration, "62:05")
    }

    // MARK: - SessionType Tests

    func testSessionTypeDisplayNames() {
        XCTAssertEqual(SessionType.checkIn.displayName, "Check-in")
        XCTAssertEqual(SessionType.deepDive.displayName, "Deep Dive")
        XCTAssertEqual(SessionType.goalReview.displayName, "Goal Review")
        XCTAssertEqual(SessionType.freeform.displayName, "Open Session")
    }

    func testSessionTypeIcons() {
        XCTAssertEqual(SessionType.checkIn.icon, "hand.wave.fill")
        XCTAssertEqual(SessionType.deepDive.icon, "arrow.down.circle.fill")
        XCTAssertEqual(SessionType.goalReview.icon, "target")
        XCTAssertEqual(SessionType.freeform.icon, "bubble.left.and.bubble.right.fill")
    }

    func testSessionTypeAllCases() {
        XCTAssertEqual(SessionType.allCases.count, 4)
    }

    // MARK: - Identifiable Tests

    func testSessionHasUniqueId() {
        let session1 = CoachingSession(userId: "user1")
        let session2 = CoachingSession(userId: "user1")

        XCTAssertNotEqual(session1.id, session2.id)
    }
}
