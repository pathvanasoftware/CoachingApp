import XCTest

final class SignInUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testSignInScreenElements() throws {
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        // Wait for the sign in screen to appear
        let appTitle = app.staticTexts["Ascendra"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5), "App title should appear")
        
        // Check Google sign in button
        let googleButton = app.buttons["Continue with Google"]
        XCTAssertTrue(googleButton.exists, "Google sign in button should exist")
        
        // Check Apple sign in button (might be a SignInWithAppleButton)
        let appleButton = app.buttons.matching(identifier: "Sign in with Apple").firstMatch
        XCTAssertTrue(appleButton.exists || app.otherElements["Sign in with Apple"].exists, 
                      "Apple sign in button should exist")
    }
    
    func testDebugModeSignIn() throws {
        app.launchArguments = ["--uitesting", "--auto-login"]
        app.launch()
        
        // Should skip sign in and go to home
        let homeTitle = app.staticTexts["Home"]
        XCTAssertTrue(homeTitle.waitForExistence(timeout: 5), "Should navigate to home with auto-login")
    }
}
