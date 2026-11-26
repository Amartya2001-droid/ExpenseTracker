import XCTest

final class ExpenseTrackerUITests: XCTestCase {
    func testRestoreRequiresReviewAndCancellationPreservesCounts() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["Add Transaction"].firstMatch.tap()
        let merchant = app.textFields["Merchant or description"]
        XCTAssertTrue(merchant.waitForExistence(timeout: 5))
        merchant.tap(); merchant.typeText("Keep me")
        let amount = app.textFields["Amount (USD)"]
        amount.tap(); amount.typeText("12.34")
        app.buttons["Save"].tap()
        app.buttons["Backup & Export"].tap()
        XCTAssertTrue(app.staticTexts["Transactions: 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Import JSON Backup"].waitForExistence(timeout: 5))
        try enterBackupJSON(app)
        XCTAssertTrue(app.staticTexts["Transactions: 1 → 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Schedules: 0 → 1"].exists)
        XCTAssertTrue(app.staticTexts["Category limits: 0 → 1"].exists)
        let added = app.staticTexts["restoreChange-transaction-77"]
        if !added.exists { app.swipeUp() }
        XCTAssertTrue(added.waitForExistence(timeout: 5))
        XCTAssertTrue(added.label.contains("Restored groceries"))
        added.tap()
        let details = app.staticTexts["restoreAfter-transaction-77"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        let data = try XCTUnwrap(details.label.data(using: .utf8))
        let row = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(row["merchant"] as? String, "Restored groceries")
        XCTAssertEqual(row["amount"] as? Double, 23.45)
        app.buttons["cancelRestorePreview"].tap()
        XCTAssertTrue(app.staticTexts["Current transactions: 1"].waitForExistence(timeout: 5))
        app.buttons["closeBackupJSONInput"].tap()
        assertExportScreenIsInteractive(app)
        XCTAssertTrue(app.staticTexts["Transactions: 1"].exists)
    }

    func testRestoreRequiresSeparateConfirmationBeforeReplacingData() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["Backup & Export"].tap()
        try enterBackupJSON(app)
        XCTAssertTrue(app.staticTexts["Transactions: 0 → 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current transactions: 0"].exists)
        app.buttons["reviewRestoreReplacement"].tap()
        XCTAssertTrue(app.buttons["Replace Ledger and Budgets"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Current transactions: 0"].exists)
        app.buttons["reviewRestoreReplacement"].tap()
        app.buttons["Replace Ledger and Budgets"].tap()
        XCTAssertTrue(app.staticTexts["Current transactions: 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current schedules: 1"].exists)
        XCTAssertTrue(app.staticTexts["Current category limits: 1"].exists)
        app.buttons["closeBackupJSONInput"].tap()
        XCTAssertTrue(app.staticTexts["Transactions: 2"].waitForExistence(timeout: 5))
    }

    private func enterBackupJSON(_ app: XCUIApplication) throws {
        app.buttons["Paste Backup JSON"].tap()
        let input = app.textViews["backupJSONInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        func transaction(_ id: Int, _ merchant: String, _ amount: Double, _ expense: Bool) -> [String: Any] {
            ["id": id, "date": "11/26/2026", "institution": "Local", "account": "Cash", "merchant": merchant,
             "amount": amount, "type": expense ? "debit" : "credit", "categoryId": 5, "category": "Food & Dining",
             "isPending": false, "isTransfer": false, "isExpense": expense, "isCashPurchase": true]
        }
        let fixture: [String: Any] = ["format": "ExpenseTracker", "version": 1, "currency": "USD", "exportedAt": "2026-11-01T00:00:00Z",
            "ledger": ["version": 1, "transactions": [transaction(77, "Restored groceries", 23.45, true), transaction(78, "Refund", 50, false)],
                       "recurringExpenses": [["id": "11111111-1111-4111-8111-111111111111", "merchant": "Future rent", "category": "Housing", "account": "Cash", "amountCents": 50000,
                                              "startDate": "01/01/2099", "frequency": "monthly", "nextIndex": 0]], "postedOccurrences": []],
            "budgets": [["month": "2026-11", "category": "Food & Dining", "limitCents": 10000]]]
        let data = try JSONSerialization.data(withJSONObject: fixture, options: [.sortedKeys])
        input.tap(); input.typeText(String(decoding: data, as: UTF8.self))
        app.buttons["validateBackupJSON"].tap()
    }

    func testExportPreviewCancellationPreservesLedger() throws {
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

        app.buttons["Export CSV"].tap()
        let preview = app.staticTexts["exportPreviewText"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertTrue(preview.label.contains("Export test expense"))
        XCTAssertTrue(preview.label.contains("\"12.34\",\"-12.34\""))
        app.buttons["cancelExportPreview"].tap()
        assertExportScreenIsInteractive(app)
        XCTAssertTrue(app.staticTexts["Transactions: 1"].exists)

        app.buttons["Export JSON Backup"].tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        let data = try XCTUnwrap(preview.label.data(using: .utf8))
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["format"] as? String, "ExpenseTracker")
        let ledger = try XCTUnwrap(json["ledger"] as? [String: Any])
        XCTAssertEqual((ledger["transactions"] as? [[String: Any]])?.count, 1)
        app.buttons["cancelExportPreview"].tap()
        assertExportScreenIsInteractive(app)
        XCTAssertTrue(app.staticTexts["Transactions: 1"].exists)
        XCTAssertFalse(app.alerts["Could Not Export"].exists)
    }

    func testCSVExportCanPresentSystemFilesPicker() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        // Teardown is cleanup, not an assertion that system cancellation works.
        defer { app.terminate() }
        app.buttons["Backup & Export"].tap()
        app.buttons["Export CSV"].tap()
        let save = app.buttons["saveExportToFiles"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(app.otherElements["Browse View (Picker)"].waitForExistence(timeout: 15))
        // Files provider save/cancel/retrieval requires the documented manual check.
    }

    private func assertExportScreenIsInteractive(_ app: XCUIApplication) {
        let button = app.buttons["Export CSV"]
        let usable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in button.isHittable }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [usable], timeout: 10), .completed)
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
