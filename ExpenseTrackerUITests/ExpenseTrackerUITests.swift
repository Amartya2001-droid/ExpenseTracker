import XCTest

final class ExpenseTrackerUITests: XCTestCase {
    func testSaveCategoryBudget() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["Budgets"].tap()
        let amount = app.textFields["Monthly limit (USD)"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("100")
        app.buttons["Save Limit"].tap()
        XCTAssertTrue(app.staticTexts["budgetFeedback"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["budgetFeedback"].label.hasPrefix("Budget saved"))
        app.buttons["Next Month"].tap()
        XCTAssertEqual(app.textFields["Monthly limit (USD)"].value as? String, "Monthly limit (USD)")
        app.buttons["Previous Month"].tap()
        XCTAssertEqual(app.textFields["Monthly limit (USD)"].value as? String, "100.00")
    }

    func testAddExpenseFromEmptyLedger() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["Add Transaction"].firstMatch.tap()
        let merchant = app.textFields["Merchant or description"]
        XCTAssertTrue(merchant.waitForExistence(timeout: 5))
        merchant.tap()
        merchant.typeText("Weekly groceries")
        let amount = app.textFields["Amount (USD)"]
        amount.tap()
        amount.typeText("12.50")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Weekly groceries"].waitForExistence(timeout: 5))
    }

    func testOverviewAndTransactionNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Overview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Total Expenses"].exists)
        app.swipeUp()
        app.buttons["See All"].tap()
        XCTAssertTrue(app.navigationBars["Transactions"].waitForExistence(timeout: 5))
    }
}
