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
}
