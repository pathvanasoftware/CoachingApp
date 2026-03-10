import XCTest
@testable import CoachingApp

final class GoalTests: XCTestCase {

    // MARK: - Initialization Tests

    func testGoalInitializationWithDefaults() {
        let goal = Goal(userId: "user1", title: "Test Goal")

        XCTAssertEqual(goal.userId, "user1")
        XCTAssertEqual(goal.title, "Test Goal")
        XCTAssertEqual(goal.description, "")
        XCTAssertEqual(goal.status, .active)
        XCTAssertEqual(goal.progress, 0.0)
        XCTAssertNil(goal.targetDate)
        XCTAssertTrue(goal.milestones.isEmpty)
        XCTAssertTrue(goal.relatedSessionIds.isEmpty)
    }

    func testGoalInitializationWithAllParameters() {
        let targetDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 1 week from now
        let milestones = [
            Milestone(title: "Milestone 1"),
            Milestone(title: "Milestone 2", isCompleted: true)
        ]

        let goal = Goal(
            userId: "user1",
            title: "Complete Project",
            description: "Finish the app",
            status: .active,
            progress: 0.5,
            targetDate: targetDate,
            milestones: milestones,
            relatedSessionIds: ["session1", "session2"]
        )

        XCTAssertEqual(goal.userId, "user1")
        XCTAssertEqual(goal.title, "Complete Project")
        XCTAssertEqual(goal.description, "Finish the app")
        XCTAssertEqual(goal.status, .active)
        XCTAssertEqual(goal.progress, 0.5)
        XCTAssertEqual(goal.targetDate, targetDate)
        XCTAssertEqual(goal.milestones.count, 2)
        XCTAssertEqual(goal.relatedSessionIds.count, 2)
    }

    // MARK: - Computed Property Tests

    func testCompletedMilestonesCount() {
        let goal = Goal(
            userId: "user1",
            title: "Test Goal",
            milestones: [
                Milestone(title: "M1", isCompleted: true),
                Milestone(title: "M2", isCompleted: false),
                Milestone(title: "M3", isCompleted: true),
                Milestone(title: "M4", isCompleted: true)
            ]
        )

        XCTAssertEqual(goal.completedMilestones, 3)
    }

    func testCompletedMilestonesWhenNoneCompleted() {
        let goal = Goal(
            userId: "user1",
            title: "Test Goal",
            milestones: [
                Milestone(title: "M1"),
                Milestone(title: "M2")
            ]
        )

        XCTAssertEqual(goal.completedMilestones, 0)
    }

    func testProgressPercentage() {
        var goal = Goal(userId: "user1", title: "Test", progress: 0.0)
        XCTAssertEqual(goal.progressPercentage, 0)

        goal = Goal(userId: "user1", title: "Test", progress: 0.5)
        XCTAssertEqual(goal.progressPercentage, 50)

        goal = Goal(userId: "user1", title: "Test", progress: 1.0)
        XCTAssertEqual(goal.progressPercentage, 100)

        goal = Goal(userId: "user1", title: "Test", progress: 0.756)
        XCTAssertEqual(goal.progressPercentage, 75)
    }

    // MARK: - GoalStatus Tests

    func testGoalStatusDisplayNames() {
        XCTAssertEqual(GoalStatus.active.displayName, "Active")
        XCTAssertEqual(GoalStatus.completed.displayName, "Completed")
        XCTAssertEqual(GoalStatus.paused.displayName, "Paused")
        XCTAssertEqual(GoalStatus.archived.displayName, "Archived")
    }

    func testGoalStatusIcons() {
        XCTAssertEqual(GoalStatus.active.icon, "flame.fill")
        XCTAssertEqual(GoalStatus.completed.icon, "checkmark.circle.fill")
        XCTAssertEqual(GoalStatus.paused.icon, "pause.circle.fill")
        XCTAssertEqual(GoalStatus.archived.icon, "archivebox.fill")
    }

    func testGoalStatusAllCases() {
        XCTAssertEqual(GoalStatus.allCases.count, 4)
    }

    // MARK: - Milestone Tests

    func testMilestoneInitializationWithDefaults() {
        let milestone = Milestone(title: "First Step")

        XCTAssertFalse(milestone.isCompleted)
        XCTAssertNil(milestone.completedAt)
    }

    func testMilestoneInitializationCompleted() {
        let completedDate = Date()
        let milestone = Milestone(
            title: "Completed Step",
            isCompleted: true,
            completedAt: completedDate
        )

        XCTAssertTrue(milestone.isCompleted)
        XCTAssertEqual(milestone.completedAt, completedDate)
    }

    // MARK: - Identifiable Tests

    func testGoalHasUniqueId() {
        let goal1 = Goal(userId: "user1", title: "Goal 1")
        let goal2 = Goal(userId: "user1", title: "Goal 2")

        XCTAssertNotEqual(goal1.id, goal2.id)
    }

    func testMilestoneHasUniqueId() {
        let milestone1 = Milestone(title: "M1")
        let milestone2 = Milestone(title: "M2")

        XCTAssertNotEqual(milestone1.id, milestone2.id)
    }
}
