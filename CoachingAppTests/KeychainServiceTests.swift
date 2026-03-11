import XCTest
@testable import CoachingApp

final class KeychainServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeychainService.deleteAccessToken()
        KeychainService.deleteRefreshToken()
    }

    override func tearDown() {
        KeychainService.deleteAccessToken()
        KeychainService.deleteRefreshToken()
        super.tearDown()
    }

    // MARK: - Access Token Tests

    func testSaveAndLoadAccessToken() {
        let token = "test-access-token-123"
        let saveResult = KeychainService.saveAccessToken(token)
        XCTAssertTrue(saveResult, "Save should succeed")
        
        let loadedToken = KeychainService.loadAccessToken()
        XCTAssertEqual(loadedToken, token, "Loaded token should match saved token")
    }

    func testDeleteAccessToken() {
        KeychainService.saveAccessToken("test-token")
        let deleteResult = KeychainService.deleteAccessToken()
        XCTAssertTrue(deleteResult, "Delete should succeed")
        
        let loadedToken = KeychainService.loadAccessToken()
        XCTAssertNil(loadedToken, "Token should be nil after deletion")
    }

    func testLoadNonExistentAccessToken() {
        KeychainService.deleteAccessToken()
        let loadedToken = KeychainService.loadAccessToken()
        XCTAssertNil(loadedToken, "Should return nil for non-existent token")
    }

    // MARK: - Refresh Token Tests

    func testSaveAndLoadRefreshToken() {
        let token = "test-refresh-token-456"
        let saveResult = KeychainService.saveRefreshToken(token)
        XCTAssertTrue(saveResult, "Save should succeed")
        
        let loadedToken = KeychainService.loadRefreshToken()
        XCTAssertEqual(loadedToken, token, "Loaded token should match saved token")
    }

    func testDeleteRefreshToken() {
        KeychainService.saveRefreshToken("test-refresh")
        let deleteResult = KeychainService.deleteRefreshToken()
        XCTAssertTrue(deleteResult, "Delete should succeed")
        
        let loadedToken = KeychainService.loadRefreshToken()
        XCTAssertNil(loadedToken, "Token should be nil after deletion")
    }

    // MARK: - Token Pair Tests

    func testSaveAndLoadBothTokens() {
        let accessToken = "access-123"
        let refreshToken = "refresh-456"
        
        KeychainService.saveAccessToken(accessToken)
        KeychainService.saveRefreshToken(refreshToken)
        
        XCTAssertEqual(KeychainService.loadAccessToken(), accessToken)
        XCTAssertEqual(KeychainService.loadRefreshToken(), refreshToken)
    }
}
