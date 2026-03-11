import XCTest
@testable import CoachingApp

final class HomeViewModelTests: XCTestCase {

    var sut: HomeViewModel!

    override func setUp() {
        super.setUp()
        sut = HomeViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.isLoading)
    }
}
