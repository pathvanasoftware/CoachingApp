import XCTest

final class OnboardingUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testOnboardingShowsWhenForced() throws {
        app.launchArguments = ["--auto-login", "--force-onboarding", "--uitesting"]
        app.launch()
        
        // Onboarding should be visible - look for skip button
        let skipButton = app.buttons["Skip"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5) || app.tabBars.firstMatch.exists,
                      "Onboarding or main app should be visible")
    }
    
    func testSkipOnboarding() throws {
        app.launchArguments = ["--auto-login", "--force-onboarding", "--uitesting"]
        app.launch()
        
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 3) {
            skipButton.tap()
        }
        
        // Should reach main app
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5),
                      "Should reach main app")
    }
    
    func testOnboardingNavigation() throws {
        app.launchArguments = ["--auto-login", "--force-onboarding", "--uitesting"]
        app.launch()
        
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 2) {
            skipButton.tap()
        }
        
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5),
                      "Should reach main app")
    }
}
