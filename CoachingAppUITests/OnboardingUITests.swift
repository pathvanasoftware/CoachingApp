import XCTest

final class OnboardingUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testOnboardingShowsWhenForced() throws {
        app.launchArguments = ["--auto-login", "--force-onboarding", "--uitesting"]
        app.launch()
        
        // Onboarding should be visible - look for any of these elements
        let skipButton = app.buttons["Skip"]
        let nextButton = app.buttons["Next"]
        let continueButton = app.buttons["Continue"]
        
        let onboardingVisible = skipButton.waitForExistence(timeout: 5) ||
                               nextButton.waitForExistence(timeout: 1) ||
                               continueButton.waitForExistence(timeout: 1)
        
        XCTAssertTrue(onboardingVisible, "Onboarding should be visible with --force-onboarding")
    }
    
    func testSkipOnboarding() throws {
        app.launchArguments = ["--auto-login", "--force-onboarding", "--uitesting"]
        app.launch()
        
        // Find and tap skip button
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 3) {
            skipButton.tap()
            
            // Should navigate to home
            let homeTab = app.tabBars.buttons["Home"]
            XCTAssertTrue(homeTab.waitForExistence(timeout: 3),
                          "Should navigate to main app after skipping onboarding")
        } else {
            // If no skip button, look for other navigation
            XCTAssertTrue(app.tabBars.firstMatch.exists, "Should show main app interface")
        }
    }
    
    func testOnboardingNavigation() throws {
        app.launchArguments = ["--auto-login", "--force-onboarding", "--uitesting"]
        app.launch()
        
        // Try to navigate through onboarding
        let nextButton = app.buttons["Next"]
        let continueButton = app.buttons["Continue"]
        let skipButton = app.buttons["Skip"]
        
        // If Next exists, tap it a few times
        if nextButton.waitForExistence(timeout: 2) {
            for _ in 0..<3 {
                if nextButton.exists {
                    nextButton.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }
        
        // Skip to finish
        if skipButton.exists {
            skipButton.tap()
        }
        
        // Should eventually reach main app
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3),
                      "Should reach main app after onboarding")
    }
}
