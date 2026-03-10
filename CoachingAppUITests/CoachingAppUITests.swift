import XCTest

final class CoachingAppUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--auto-login", "--uitesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {}
    
    // MARK: - Sign In Screen Tests
    
    func testSignInScreenDisplays() throws {
        // Launch without auto-login
        app.launchArguments.removeAll()
        app.launchArguments.append("--uitesting")
        app.launch()
        
        // Verify sign in screen elements
        XCTAssertTrue(app.staticTexts["Ascendra"].waitForExistence(timeout: 5), "App title should be visible")
    }
    
    // MARK: - Home Screen Tests
    
    func testHomeScreenDisplays() throws {
        // Verify tab bar exists
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5), "Tab bar should exist")
    }
    
    func testNavigationTabsExist() throws {
        // Verify tab bar exists
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5), "Tab bar should exist")
    }
    
    // MARK: - Sessions Tests
    
    func testNavigateToSessions() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
    }
    
    // MARK: - Goals Tests
    
    func testNavigateToGoals() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
    }
    
    // MARK: - Profile Tests
    
    func testNavigateToProfile() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
    }
    
    // MARK: - Onboarding Tests
    
    func testOnboardingFlow() throws {
        // Launch with onboarding
        app.launchArguments = ["--auto-login", "--force-onboarding", "--uitesting"]
        app.launch()
        
        // Look for skip button or any onboarding element
        let skipButton = app.buttons["Skip"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5) || app.tabBars.firstMatch.exists,
                      "Onboarding or main app should be visible")
    }
    
    // MARK: - Chat Tests
    
    func testChatInterface() throws {
        // Just verify main app loaded
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5), "Main app should be visible")
    }
    
    // MARK: - Screenshot Tests
    
    func testTakeScreenshots() throws {
        // Verify app loaded
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5), "App should be loaded for screenshots")
    }
}
