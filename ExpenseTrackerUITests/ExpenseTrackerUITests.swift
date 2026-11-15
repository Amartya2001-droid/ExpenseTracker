import XCTest

final class ExpenseTrackerUITests: XCTestCase {
    func testExportShowsSourceCountsAndCanCancelSaveDialog() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["Add Transaction"].firstMatch.tap()
        let merchant = app.textFields["Merchant or description"]
        XCTAssertTrue(merchant.waitForExistence(timeout: 5))
        merchant.tap(); merchant.typeText("Export test expense")
        let amount = app.textFields["Amount (USD)"]
        amount.tap(); amount.typeText("12.34")
        app.buttons["Save"].tap()
        app.buttons["Backup & Export"].tap()
        XCTAssertTrue(app.staticTexts["Transactions: 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Schedules: 0"].exists)
        XCTAssertTrue(app.staticTexts["Category limits: 0"].exists)
        XCTAssertTrue(app.buttons["Export JSON Backup"].exists)
        app.buttons["Export CSV"].tap()
        let picker = app.otherElements["Browse View (Picker)"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15))
        // Files exposes this control as Other on the CI simulator, not Button.
        let cancel = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch
        let presented = cancel.waitForExistence(timeout: 15)
        if !presented { print("EXPORT PRESENTATION HIERARCHY: " + app.debugDescription) }
        XCTAssertTrue(presented)
        cancel.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: picker)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
        XCTAssertFalse(app.alerts["Could Not Export"].exists)
        XCTAssertTrue(app.staticTexts["Transactions: 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Export CSV"].exists)
    }

    func testRecurringSchedulePostsIntoLedger() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["Recurring"].tap()
        app.buttons["Add Schedule"].tap()
        let description = app.textFields["Recurring description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        description.tap(); description.typeText("Monthly subscription")
        let amount = app.textFields["Recurring amount (USD)"]
        amount.tap(); amount.typeText("15")
        app.buttons["Save Schedule"].tap()
        XCTAssertTrue(app.staticTexts["Monthly subscription"].waitForExistence(timeout: 5))
        app.buttons["Post Due"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Monthly subscription"].waitForExistence(timeout: 5))
    }

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
