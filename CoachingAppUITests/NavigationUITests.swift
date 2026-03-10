import XCTest

final class NavigationUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["--auto-login", "--uitesting"]
        app.launch()
    }
    
    func testAllTabsAccessible() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")
        
        // Test Home tab
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["Home"].exists, "Home tab should show Home view")
        
        // Test Sessions tab
        app.tabBars.buttons["Sessions"].tap()
        XCTAssertTrue(app.staticTexts["Sessions"].exists, "Sessions tab should show Sessions view")
        
        // Test Goals tab
        app.tabBars.buttons["Goals"].tap()
        XCTAssertTrue(app.staticTexts["Goals"].exists, "Goals tab should show Goals view")
        
        // Test Profile tab
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].exists, "Profile tab should show Profile view")
    }
    
    func testTabNavigationOrder() throws {
        // Navigate through tabs in order
        let tabs = ["Sessions", "Goals", "Profile", "Home"]
        
        for tab in tabs {
            app.tabBars.buttons[tab].tap()
            // Small delay for animation
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Should be back on Home
        XCTAssertTrue(app.staticTexts["Home"].exists, "Should end up on Home tab")
    }
}
