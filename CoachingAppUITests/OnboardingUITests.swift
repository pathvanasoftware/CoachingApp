import XCTest

final class OnboardingUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--auto-login", "--force-onboarding", "--uitesting"]
    }
    
    func testOnboardingWelcomeStep() throws {
        app.launchArguments.append("--onboarding-step=0")
        app.launch()
        
        // Verify welcome step
        XCTAssertTrue(app.staticTexts["Welcome"].exists || app.staticTexts["Welcome to Ascendra"].exists,
                      "Welcome step should be visible")
    }
    
    func testOnboardingAssessmentStep() throws {
        app.launchArguments.append("--onboarding-step=1")
        app.launch()
        
        // Verify assessment step
        XCTAssertTrue(app.staticTexts["About You"].exists || app.staticTexts["Assessment"].exists,
                      "Assessment step should be visible")
    }
    
    func testOnboardingCoachingStyleStep() throws {
        app.launchArguments.append("--onboarding-step=2")
        app.launch()
        
        // Verify coaching style step
        XCTAssertTrue(app.staticTexts["Coaching Style"].exists,
                      "Coaching style step should be visible")
    }
    
    func testOnboardingFirstGoalStep() throws {
        app.launchArguments.append("--onboarding-step=3")
        app.launch()
        
        // Verify first goal step
        XCTAssertTrue(app.staticTexts["First Goal"].exists || app.staticTexts["Goal"].exists,
                      "First goal step should be visible")
    }
    
    func testSkipOnboarding() throws {
        app.launch()
        
        // Find and tap skip button
        let skipButton = app.buttons["Skip"]
        if skipButton.waitForExistence(timeout: 2) {
            skipButton.tap()
            
            // Should navigate to home
            XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 3),
                          "Should navigate to home after skipping onboarding")
        }
    }
}
