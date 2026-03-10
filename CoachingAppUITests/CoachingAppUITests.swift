import XCTest

final class CoachingAppUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        // Setup before each test
        continueAfterFailure = false
        
        // Launch with auto-login for most tests
        app.launchArguments = ["--auto-login", "--uitesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        // Cleanup after each test
    }
    
    // MARK: - Sign In Screen Tests
    
    func testSignInScreenDisplays() throws {
        // Launch without auto-login
        app.launchArguments.removeAll()
        app.launchArguments.append("--uitesting")
        app.launch()
        
        // Verify sign in screen elements
        XCTAssertTrue(app.staticTexts["Ascendra"].exists, "App title should be visible")
        XCTAssertTrue(app.buttons["Continue with Google"].exists, "Google sign in button should exist")
        XCTAssertTrue(app.buttons["Sign in with Apple"].exists, "Apple sign in button should exist")
    }
    
    // MARK: - Home Screen Tests
    
    func testHomeScreenDisplays() throws {
        // Verify home screen elements
        XCTAssertTrue(app.staticTexts["Home"].exists, "Home navigation title should exist")
        XCTAssertTrue(app.buttons["Start Session"].exists || app.buttons["Daily Check-In"].exists, 
                      "Start session button should exist")
    }
    
    func testNavigationTabsExist() throws {
        // Verify all tab bar items exist
        XCTAssertTrue(app.tabBars.buttons["Home"].exists, "Home tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Sessions"].exists, "Sessions tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Goals"].exists, "Goals tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists, "Profile tab should exist")
    }
    
    // MARK: - Sessions Tests
    
    func testNavigateToSessions() throws {
        app.tabBars.buttons["Sessions"].tap()
        
        XCTAssertTrue(app.staticTexts["Sessions"].exists, "Sessions title should be visible")
    }
    
    // MARK: - Goals Tests
    
    func testNavigateToGoals() throws {
        app.tabBars.buttons["Goals"].tap()
        
        XCTAssertTrue(app.staticTexts["Goals"].exists, "Goals title should be visible")
    }
    
    // MARK: - Profile Tests
    
    func testNavigateToProfile() throws {
        app.tabBars.buttons["Profile"].tap()
        
        XCTAssertTrue(app.staticTexts["Profile"].exists, "Profile title should be visible")
    }
    
    // MARK: - Onboarding Tests
    
    func testOnboardingFlow() throws {
        // Launch with onboarding
        app.launchArguments = ["--auto-login", "--force-onboarding", "--uitesting"]
        app.launch()
        
        // Should show onboarding
        XCTAssertTrue(app.buttons["Skip"].waitForExistence(timeout: 5), 
                      "Skip button should be visible on onboarding")
        
        // Skip onboarding
        if app.buttons["Skip"].exists {
            app.buttons["Skip"].tap()
        }
        
        // Should now be on home screen
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3), "Should navigate to main app after skipping onboarding")
    }
    
    // MARK: - Chat Tests
    
    func testChatInterface() throws {
        // Navigate to chat (tap start session if available)
        if app.buttons["Start Session"].exists {
            app.buttons["Start Session"].tap()
        } else if app.buttons["Daily Check-In"].exists {
            app.buttons["Daily Check-In"].tap()
        }
        
        // Verify chat interface elements
        // Chat should have a text input field
        XCTAssertTrue(app.textFields.firstMatch.exists || app.textViews.firstMatch.exists, 
                      "Chat input should exist")
    }
    
    // MARK: - Screenshot Tests
    
    func testTakeScreenshots() throws {
        // Home screen
        takeScreenshot(named: "01_Home")
        
        // Sessions
        app.tabBars.buttons["Sessions"].tap()
        takeScreenshot(named: "02_Sessions")
        
        // Goals
        app.tabBars.buttons["Goals"].tap()
        takeScreenshot(named: "03_Goals")
        
        // Profile
        app.tabBars.buttons["Profile"].tap()
        takeScreenshot(named: "04_Profile")
    }
    
    // MARK: - Helpers
    
    private func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
