import XCTest
@testable import ExpenseTracker

final class ExpenseTrackerTests: XCTestCase {
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
