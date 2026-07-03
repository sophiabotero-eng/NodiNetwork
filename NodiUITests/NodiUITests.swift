import XCTest

final class NodiUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_launchShowsWelcomeScreenWhenSignedOut() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Nodi"].waitForExistence(timeout: 5))
    }

    func test_continueWithEmailOpensAuthSheet() throws {
        let app = XCUIApplication()
        app.launch()

        let emailButton = app.buttons["Continue with Email"]
        XCTAssertTrue(emailButton.waitForExistence(timeout: 5))
        emailButton.tap()

        XCTAssertTrue(app.navigationBars["Sign In"].waitForExistence(timeout: 5))
    }
}
