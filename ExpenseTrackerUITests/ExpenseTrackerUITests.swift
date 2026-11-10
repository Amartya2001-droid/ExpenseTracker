import XCTest

final class ExpenseTrackerUITests: XCTestCase {
    func testOverviewAndTransactionNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Overview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Total Expenses"].exists)
        app.buttons["See All"].tap()
        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 5))
    }
}
