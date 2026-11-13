import XCTest
@testable import ExpenseTracker

final class ExpenseTrackerTests: XCTestCase {
    private func entry(id: Int = 100, amount: Double = 12.50, date: String = "11/11/2026", expense: Bool = true) -> Transaction {
        Transaction(id: id, date: date, institution: "Local", account: "Cash", merchant: "Groceries", amount: amount, type: expense ? "debit" : "credit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: expense, isCashPurchase: true)
    }

    func testLedgerCreateEditDeleteSurvivesReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("ledger.json")
        let model = TransactionListViewModel(fetchOnInit: false, storageURL: url)
        XCTAssertTrue(model.transactions.isEmpty)
        try model.save(entry())
        try model.save(entry(id: 101, amount: 100, expense: false))
        let reloaded = TransactionListViewModel(fetchOnInit: false, storageURL: url)
        XCTAssertEqual(reloaded.transactions.count, 2)
        XCTAssertEqual(reloaded.balance, 87.50, accuracy: 0.001)
        try reloaded.save(entry(amount: 20))
        XCTAssertEqual(reloaded.transactions.count, 2)
        XCTAssertEqual(reloaded.totalExpenses, 20)
        try reloaded.delete([100])
        let final = TransactionListViewModel(fetchOnInit: false, storageURL: url)
        XCTAssertEqual(final.transactions.map(\.id), [101])
        XCTAssertEqual(final.balance, 100)
    }

    func testInvalidInputCannotMutateLedger() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        for amount in [0.0, -1, Double.nan, Double.infinity, 1.234] {
            XCTAssertThrowsError(try model.save(entry(amount: amount)))
        }
        for date in ["bad", "02/29/2025", "13/01/2026", "4/12/2026"] {
            XCTAssertNil(date.validTransactionDate)
            XCTAssertThrowsError(try model.save(entry(date: date)))
        }
        XCTAssertTrue(model.transactions.isEmpty)
    }

    func testCorruptLedgerIsPreservedAndWritesAreBlocked() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data("not a ledger".utf8)
        try original.write(to: url)
        let model = TransactionListViewModel(fetchOnInit: false, storageURL: url)
        XCTAssertNotNil(model.storageError)
        XCTAssertThrowsError(try model.save(entry()))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testWriteFailureDoesNotChangeBalance() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = TransactionListViewModel(fetchOnInit: false, storageURL: directory.appendingPathComponent("ledger.json"))
        // A file where the parent directory should be forces an actual write failure.
        try Data("blocked".utf8).write(to: directory)
        XCTAssertThrowsError(try model.save(entry()))
        XCTAssertTrue(model.transactions.isEmpty)
    }

    func testSearchMonthlyTotalsAndExplicitSamples() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        try model.save(entry())
        try model.save(entry(id: 101, amount: 100, expense: false))
        try model.save(entry(id: 102, amount: 20, date: "10/01/2026"))
        XCTAssertEqual(model.filteredTransactions(search: "gRoCeRiEs", expensesOnly: true).count, 2)
        XCTAssertTrue(model.filteredTransactions(search: "missing").isEmpty)
        XCTAssertEqual(model.expenses(inMonth: "11/01/2026".dateParsed()), 12.50)
        try model.loadSampleData()
        XCTAssertEqual(model.transactions.count, 3, "Sample action must not overwrite a personal ledger")
    }

    func testCurrencyInputRequiresCompletePositiveDecimalAmount() throws {
        XCTAssertEqual(try Transaction.parseAmount("12,50", locale: Locale(identifier: "de_DE")), 12.5)
        XCTAssertThrowsError(try Transaction.parseAmount("1.00", locale: Locale(identifier: "de_DE")))
        XCTAssertEqual(try Transaction.parseAmount("12.50", locale: Locale(identifier: "en_US")), 12.5)
        for input in ["", "0", "-1", "1.234", "12abc", "NaN", "1,000", "1000000000"] {
            XCTAssertThrowsError(try Transaction.parseAmount(input, locale: Locale(identifier: "en_US")))
        }
    }

    func testFixedFormatDatesUseGregorianYearsAndMonthDayOrder() {
        let calendar = Calendar(identifier: .gregorian)
        for (input, year, month, day) in [("04/12/2026", 2026, 4, 12),
                                         ("02/29/2024", 2024, 2, 29),
                                         ("12/31/2025", 2025, 12, 31)] {
            let components = calendar.dateComponents([.year, .month, .day], from: input.dateParsed())
            XCTAssertEqual(components.year, year, input)
            XCTAssertEqual(components.month, month, input)
            XCTAssertEqual(components.day, day, input)
        }
    }

    func testRecentTransactionsAreNewestFirstAndLimitedToFive() {
        let model = TransactionListViewModel(fetchOnInit: false)
        model.transactions = Transaction.all.sorted { $0.parsedDate < $1.parsedDate }
        let recent = model.recentTransactions
        XCTAssertEqual(recent.count, 5)
        XCTAssertEqual(Set(recent.map(\.id)), Set([1, 2, 3, 4, 5]))
        XCTAssertTrue(zip(recent, recent.dropFirst()).allSatisfy { $0.parsedDate >= $1.parsedDate })
    }

    func testTotalsExcludeIncomeAndEmptyInputIsSafe() {
        let model = TransactionListViewModel(fetchOnInit: false)
        XCTAssertEqual(model.totalExpenses, 0)
        XCTAssertTrue(model.recentTransactions.isEmpty)
        XCTAssertTrue(model.groupTransactionsByMonth().isEmpty)
        XCTAssertTrue(model.accumulateTransactions().isEmpty)
        model.transactions = Transaction.all.filter { [1, 2, 10].contains($0.id) }
        XCTAssertEqual(model.totalExpenses, 16.98, accuracy: 0.001)
    }
}
