import XCTest

final class SignInUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testSignInScreenElements() throws {
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        let appTitle = app.staticTexts["Ascendra"]
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5), "App title should appear")
    }
    
    func testDebugModeSignIn() throws {
        app.launchArguments = ["--uitesting", "--auto-login"]
        app.launch()
        
        // Should skip sign in and go to main app
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5),
                      "Should navigate to main app with auto-login")
    }
}
