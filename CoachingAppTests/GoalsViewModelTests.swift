import XCTest
@testable import CoachingApp

final class GoalsViewModelTests: XCTestCase {

    var sut: GoalsViewModel!
    var mockGoalService: MockGoalService!

    override func setUp() {
        super.setUp()
        mockGoalService = MockGoalService()
        sut = GoalsViewModel(goalService: mockGoalService)
    }

    override func tearDown() {
        sut = nil
        mockGoalService = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertTrue(sut.goals.isEmpty)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Load Goals Tests

    func testLoadGoalsSuccess() async {
        await sut.loadGoals()

        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.goals)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - Filter Tests

    func testFilteredGoalsReturnsAllWhenNoFilter() {
        sut.goals = [
            Goal(userId: "1", title: "Goal 1", description: "", status: .active),
            Goal(userId: "1", title: "Goal 2", description: "", status: .completed)
        ]
        sut.selectedFilter = nil

        XCTAssertEqual(sut.filteredGoals.count, 2)
    }

    func testFilteredGoalsReturnsOnlyActive() {
        sut.goals = [
            Goal(userId: "1", title: "Goal 1", description: "", status: .active),
            Goal(userId: "1", title: "Goal 2", description: "", status: .completed)
        ]
        sut.selectedFilter = .active

        XCTAssertEqual(sut.filteredGoals.count, 1)
        XCTAssertEqual(sut.filteredGoals.first?.status, .active)
    }

    // MARK: - Count Tests

    func testActiveGoalsCount() {
        sut.goals = [
            Goal(userId: "1", title: "Goal 1", description: "", status: .active),
            Goal(userId: "1", title: "Goal 2", description: "", status: .active),
            Goal(userId: "1", title: "Goal 3", description: "", status: .completed)
        ]

        XCTAssertEqual(sut.activeGoalsCount, 2)
    }

    func testCompletedGoalsCount() {
        sut.goals = [
            Goal(userId: "1", title: "Goal 1", description: "", status: .active),
            Goal(userId: "1", title: "Goal 2", description: "", status: .completed),
            Goal(userId: "1", title: "Goal 3", description: "", status: .completed)
        ]

        XCTAssertEqual(sut.completedGoalsCount, 2)
    }
}
