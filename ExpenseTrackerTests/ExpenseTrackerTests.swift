import XCTest
@testable import ExpenseTracker

final class ExpenseTrackerTests: XCTestCase {
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
