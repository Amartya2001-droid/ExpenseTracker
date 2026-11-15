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

final class BudgetTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private func entry(id: Int, date: String = "11/13/2026", amount: Double, category: String = "Food & Dining", expense: Bool = true, transfer: Bool = false) -> Transaction {
        Transaction(id: id, date: date, institution: "Local", account: "Cash", merchant: "Test", amount: amount, type: expense ? "debit" : "credit", categoryId: 5, category: category, isPending: false, isTransfer: transfer, isExpense: expense, isCashPurchase: true)
    }

    func testBudgetCreateUpdateRemoveAndReloadKeepsOtherMonths() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("budgets.json")
        let store = BudgetStore(inMemory: true, storageURL: url)
        try store.setLimit(month: "2026-11", category: "Food & Dining", amount: "100.01", locale: locale)
        try store.setLimit(month: "2026-12", category: "Food & Dining", amount: "200", locale: locale)
        try store.setLimit(month: "2026-11", category: "Shopping", amount: "50", locale: locale)
        try store.setLimit(month: "2026-11", category: "Food & Dining", amount: "125.25", locale: locale)
        let reloaded = BudgetStore(inMemory: true, storageURL: url)
        XCTAssertEqual(reloaded.budgets.count, 3)
        XCTAssertEqual(reloaded.budgets.first { $0.month == "2026-11" && $0.category == "Food & Dining" }?.limitCents, 12525)
        try reloaded.remove(month: "2026-11", category: "Food & Dining")
        let final = BudgetStore(inMemory: true, storageURL: url)
        XCTAssertEqual(final.budgets.count, 2)
        XCTAssertEqual(final.budgets.first { $0.month == "2026-12" }?.limitCents, 20000)
    }

    func testInsightsIncludeUnbudgetedSpendingAndExcludeIncomeTransfersAndOtherMonths() throws {
        let store = BudgetStore(inMemory: true)
        try store.setLimit(month: "2026-11", category: "Food & Dining", amount: "10", locale: locale)
        try store.setLimit(month: "2026-11", category: "Housing", amount: "500", locale: locale)
        let transactions = [entry(id: 1, amount: 7.10), entry(id: 2, amount: 5.20),
                            entry(id: 3, amount: 50, expense: false), entry(id: 4, amount: 90, transfer: true),
                            entry(id: 5, date: "12/01/2026", amount: 80), entry(id: 6, amount: 3, category: "Shopping")]
        let rows = store.insights(for: "2026-11", transactions: transactions)
        XCTAssertEqual(rows.map(\.category), ["Food & Dining", "Shopping", "Housing"])
        XCTAssertEqual(rows[0].spentCents, 1230)
        XCTAssertEqual(rows[0].remainingCents, -230)
        XCTAssertEqual(rows[0].progress, 1)
        XCTAssertNil(rows[1].limitCents)
        XCTAssertNil(rows[1].remainingCents)
        XCTAssertEqual(rows[2].remainingCents, 50000)
        XCTAssertEqual(rows[2].progress, 0)
        try store.remove(month: "2026-11", category: "Food & Dining")
        XCTAssertEqual(store.insights(for: "2026-11", transactions: transactions)[0].spentCents, 1230)
    }

    func testBudgetAtLimitAndBelowLimitUseExactCents() throws {
        let store = BudgetStore(inMemory: true)
        try store.setLimit(month: "2026-11", category: "Food & Dining", amount: "0.30", locale: locale)
        let rows = store.insights(for: "2026-11", transactions: [entry(id: 1, amount: 0.1), entry(id: 2, amount: 0.2)])
        XCTAssertEqual(rows[0].remainingCents, 0)
        XCTAssertEqual(rows[0].progress, 1)
        let below = store.insights(for: "2026-11", transactions: [entry(id: 1, amount: 0.1)])
        XCTAssertEqual(below[0].remainingCents, 20)
        XCTAssertEqual(below[0].progress, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertTrue(store.insights(for: "2027-11", transactions: [entry(id: 1, amount: 1)]).isEmpty)
    }

    func testInvalidBudgetsLeaveStoreUnchangedAndSupportLocalDecimalSeparator() throws {
        let store = BudgetStore(inMemory: true)
        for month in ["2026-00", "2026-13", "0000-01", "2026-1", "2026-11\n", "bad"] {
            XCTAssertThrowsError(try store.setLimit(month: month, category: "Food", amount: "10", locale: locale))
        }
        for amount in ["0", "-1", "1.001", "NaN", "1000000000"] {
            XCTAssertThrowsError(try store.setLimit(month: "2026-11", category: "Food", amount: amount, locale: locale))
        }
        XCTAssertThrowsError(try store.setLimit(month: "2026-11", category: "  ", amount: "10", locale: locale))
        XCTAssertTrue(store.budgets.isEmpty)
        try store.setLimit(month: "2026-11", category: "Food", amount: "10,25", locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(store.budgets[0].limitCents, 1025)
        XCTAssertEqual(BudgetStore.monthKey(for: "01/01/2027".dateParsed()), "2027-01")
    }

    func testCorruptAndDuplicateBudgetFilesArePreservedAndBlockChanges() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let budget = CategoryBudget(month: "2026-11", category: "Food", limitCents: 100)
        for data in [Data("bad json".utf8), try JSONEncoder().encode([budget, budget]),
                     try JSONEncoder().encode([CategoryBudget(month: "2026-13", category: "Food", limitCents: 0)])] {
            try data.write(to: url)
            let store = BudgetStore(inMemory: true, storageURL: url)
            XCTAssertNotNil(store.storageError)
            XCTAssertThrowsError(try store.setLimit(month: "2026-11", category: "Food", amount: "10", locale: locale))
            XCTAssertThrowsError(try store.remove(month: "2026-11", category: "Food"))
            XCTAssertEqual(try Data(contentsOf: url), data)
        }
    }

    func testBudgetWriteFailureLeavesStateUnchanged() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: parent) }
        let store = BudgetStore(inMemory: true, storageURL: parent.appendingPathComponent("budgets.json"))
        try Data("blocked".utf8).write(to: parent)
        XCTAssertThrowsError(try store.setLimit(month: "2026-11", category: "Food", amount: "10", locale: locale))
        XCTAssertTrue(store.budgets.isEmpty)
        XCTAssertEqual(try Data(contentsOf: parent), Data("blocked".utf8))
    }
}

extension BudgetTests {
    func testBudgetChangesDoNotRewriteTransactionLedger() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledgerURL = directory.appendingPathComponent("transactions.json")
        let model = TransactionListViewModel(fetchOnInit: false, storageURL: ledgerURL)
        try model.save(entry(id: 1, amount: 5))
        let original = try Data(contentsOf: ledgerURL)
        let store = BudgetStore(inMemory: true, storageURL: directory.appendingPathComponent("budgets.json"))
        try store.setLimit(month: "2026-11", category: "Food & Dining", amount: "50", locale: locale)
        try store.remove(month: "2026-11", category: "Food & Dining")
        XCTAssertEqual(try Data(contentsOf: ledgerURL), original)
        XCTAssertEqual(TransactionListViewModel(fetchOnInit: false, storageURL: ledgerURL).transactions.count, 1)
    }
}

final class RecurringExpenseTests: XCTestCase {
    private func rule(start: String = "01/31/2026", frequency: RecurringExpense.Frequency = .monthly, cents: Int64 = 1299) -> RecurringExpense {
        RecurringExpense(merchant: "Subscription", category: "Entertainment", account: "Card", amountCents: cents, startDate: start, frequency: frequency)
    }

    func testMonthlySchedulesClampWithoutDriftIncludingLeapYears() {
        let monthly = rule()
        XCTAssertEqual((0...3).compactMap { monthly.occurrence(at: $0).map(RecurringExpense.dateString) }, ["01/31/2026", "02/28/2026", "03/31/2026", "04/30/2026"])
        XCTAssertEqual(rule(start: "01/31/2024").occurrence(at: 1).map(RecurringExpense.dateString), "02/29/2024")
        XCTAssertEqual(rule(start: "12/31/2026").occurrence(at: 1).map(RecurringExpense.dateString), "01/31/2027")
        XCTAssertNil(monthly.occurrence(at: -1))
        XCTAssertNil(monthly.occurrence(at: Int.max))
    }

    func testWeeklyScheduleUsesLocalCalendarDaysAcrossYearAndDSTBoundaries() {
        XCTAssertEqual(rule(start: "12/28/2026", frequency: .weekly).occurrence(at: 1).map(RecurringExpense.dateString), "01/04/2027")
        XCTAssertEqual(rule(start: "03/07/2026", frequency: .weekly).occurrence(at: 1).map(RecurringExpense.dateString), "03/14/2026")
    }

    func testPostingIsIdempotentAndFutureOccurrencesDoNotAffectBalances() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        let schedule = rule()
        try model.saveRecurring(schedule)
        XCTAssertEqual(try model.postDueExpenses(through: "01/30/2026".dateParsed()), 0)
        XCTAssertTrue(model.transactions.isEmpty)
        XCTAssertEqual(try model.postDueExpenses(through: "02/28/2026".dateParsed()), 2)
        XCTAssertEqual(try model.postDueExpenses(through: "02/28/2026".dateParsed()), 0)
        XCTAssertEqual(model.transactions.map(\.date), ["01/31/2026", "02/28/2026"])
        XCTAssertTrue(model.transactions.allSatisfy { $0.recurringID == schedule.id && $0.isExpense })
        XCTAssertEqual(model.totalExpenses, 25.98, accuracy: 0.0001)
        XCTAssertEqual(model.expenses(inMonth: "02/01/2026".dateParsed()), 12.99, accuracy: 0.0001)
    }

    func testLegacyMigrationReloadAndDeletedOccurrenceProtection() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("transactions.json")
        let legacy = [Transaction.all[0]]
        try JSONEncoder().encode(legacy).write(to: url)
        let model = TransactionListViewModel(fetchOnInit: false, storageURL: url)
        XCTAssertEqual(model.transactions, legacy)
        let schedule = rule()
        try model.saveRecurring(schedule)
        XCTAssertEqual(try model.postDueExpenses(through: "01/31/2026".dateParsed()), 1)
        let occurrence = try XCTUnwrap(model.transactions.first { $0.recurringID != nil })
        try model.delete([occurrence.id])
        let reloaded = TransactionListViewModel(fetchOnInit: false, storageURL: url)
        XCTAssertEqual(reloaded.transactions, legacy)
        XCTAssertEqual(try reloaded.postDueExpenses(through: "01/31/2026".dateParsed()), 0)
        var edited = schedule
        edited.amountCents = 2000
        try reloaded.saveRecurring(edited, today: "01/31/2026".dateParsed())
        XCTAssertEqual(try reloaded.postDueExpenses(through: "01/31/2026".dateParsed()), 0, "A reset schedule cannot recreate a deleted occurrence")
        XCTAssertEqual(try reloaded.postDueExpenses(through: "02/28/2026".dateParsed()), 1)
        XCTAssertEqual(reloaded.transactions.last?.amount, 20)
        let snapshot = try JSONDecoder().decode(LedgerSnapshot.self, from: Data(contentsOf: url))
        XCTAssertEqual(snapshot.version, 1)
        XCTAssertEqual(snapshot.postedOccurrences.count, 2)
    }

    func testEditingFutureAmountPreservesMonthEndAnchorAndPostedHistory() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        let schedule = rule()
        try model.saveRecurring(schedule)
        try model.postDueExpenses(through: "01/31/2026".dateParsed())
        var edited = schedule
        edited.startDate = "02/28/2026"
        edited.amountCents = 2000
        try model.saveRecurring(edited, today: "02/01/2026".dateParsed())
        try model.postDueExpenses(through: "03/31/2026".dateParsed())
        XCTAssertEqual(model.transactions.map(\.date), ["01/31/2026", "02/28/2026", "03/31/2026"])
        XCTAssertEqual(model.transactions.map(\.amount), [12.99, 20, 20])
        try model.deleteRecurring(schedule.id)
        XCTAssertTrue(model.recurringExpenses.isEmpty)
        XCTAssertEqual(try model.postDueExpenses(through: "12/31/2026".dateParsed()), 0)
        XCTAssertEqual(model.transactions.count, 3)
    }

    func testEditedOccurrenceKeepsItsRecurringIdentity() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        try model.saveRecurring(rule())
        try model.postDueExpenses(through: "01/31/2026".dateParsed())
        let transaction = try XCTUnwrap(model.transactions.first)
        let edited = Transaction(id: transaction.id, date: transaction.date, institution: transaction.institution,
            account: transaction.account, merchant: "Edited subscription", amount: 42, type: transaction.type,
            categoryId: transaction.categoryId, category: transaction.category, isPending: false,
            isTransfer: false, isExpense: true, isCashPurchase: false, recurringID: transaction.recurringID)
        try model.save(edited)
        XCTAssertEqual(try model.postDueExpenses(through: "01/31/2026".dateParsed()), 0)
        XCTAssertEqual(model.transactions.first?.recurringID, transaction.recurringID)
        XCTAssertEqual(model.transactions.first?.merchant, "Edited subscription")
        XCTAssertEqual(model.totalExpenses, 42)
    }

    func testScheduleReschedulingAndInvalidInputs() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        for cents in [Int64(0), -1, 100_000_000_000] {
            XCTAssertThrowsError(try model.saveRecurring(rule(cents: cents)))
        }
        XCTAssertThrowsError(try model.saveRecurring(rule(start: "02/29/2025")))
        var invalid = rule(); invalid.merchant = "  "
        XCTAssertThrowsError(try model.saveRecurring(invalid))
        XCTAssertTrue(model.recurringExpenses.isEmpty)
        let schedule = rule()
        try model.saveRecurring(schedule)
        var changed = schedule
        changed.startDate = "02/01/2026"
        XCTAssertThrowsError(try model.saveRecurring(changed, today: "02/02/2026".dateParsed()))
        changed.startDate = "02/02/2026"; changed.frequency = .weekly
        try model.saveRecurring(changed, today: "02/02/2026".dateParsed())
        XCTAssertEqual(try model.postDueExpenses(through: "02/09/2026".dateParsed()), 2)
        XCTAssertEqual(model.transactions.map(\.date), ["02/02/2026", "02/09/2026"])
    }

    func testCatchUpIsBoundedAndCanResume() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        try model.saveRecurring(rule(start: "01/01/2010", frequency: .weekly))
        XCTAssertEqual(try model.postDueExpenses(through: "01/01/2026".dateParsed()), 500)
        let next = model.recurringExpenses[0].nextIndex
        XCTAssertEqual(next, 500)
        let second = try model.postDueExpenses(through: "01/01/2026".dateParsed())
        XCTAssertGreaterThan(second, 0)
        XCTAssertLessThan(second, 500)
        XCTAssertEqual(try model.postDueExpenses(through: "01/01/2026".dateParsed()), 0)
        XCTAssertEqual(Set(model.transactions.map(\.id)).count, model.transactions.count)
    }

    func testFailedPostingCommitsNeitherEntriesNorCheckpoints() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("transactions.json")
        let model = TransactionListViewModel(fetchOnInit: false, storageURL: url)
        try model.saveRecurring(rule())
        let original = try Data(contentsOf: url)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        XCTAssertThrowsError(try model.postDueExpenses(through: "01/31/2026".dateParsed()))
        XCTAssertTrue(model.transactions.isEmpty)
        XCTAssertEqual(model.recurringExpenses[0].nextIndex, 0)
        try FileManager.default.removeItem(at: url)
        try original.write(to: url)
        let reloaded = TransactionListViewModel(fetchOnInit: false, storageURL: url)
        XCTAssertEqual(try reloaded.postDueExpenses(through: "01/31/2026".dateParsed()), 1)
        XCTAssertEqual(try reloaded.postDueExpenses(through: "01/31/2026".dateParsed()), 0)
    }

    func testCorruptSnapshotPreservedAndScheduleMutationsBlocked() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let schedule = rule()
        var unknown = LedgerSnapshot(transactions: [], recurringExpenses: [], postedOccurrences: [])
        unknown.version = 2
        for snapshot in [unknown, LedgerSnapshot(transactions: [], recurringExpenses: [schedule, schedule], postedOccurrences: []),
                         LedgerSnapshot(transactions: [], recurringExpenses: [], postedOccurrences: ["invalid"])] {
            let original = try JSONEncoder().encode(snapshot)
            try original.write(to: url)
            let model = TransactionListViewModel(fetchOnInit: false, storageURL: url)
            XCTAssertNotNil(model.storageError)
            XCTAssertThrowsError(try model.saveRecurring(schedule))
            XCTAssertThrowsError(try model.deleteRecurring(schedule.id))
            XCTAssertThrowsError(try model.postDueExpenses())
            XCTAssertEqual(try Data(contentsOf: url), original)
        }
    }
}

final class LedgerExportTests: XCTestCase {
    private func entry(id: Int = 1, date: String = "11/15/2026", merchant: String = "Coffee", amount: Double = 12.34,
                       expense: Bool = true, category: String = "Food & Dining", account: String = "Cash",
                       institution: String = "Local", type: String = "debit") -> Transaction {
        Transaction(id: id, date: date, institution: institution, account: account, merchant: merchant, amount: amount,
            type: type, categoryId: 5, category: category, isPending: false, isTransfer: false, isExpense: expense, isCashPurchase: true)
    }

    private func decode(_ data: Data) throws -> LedgerBackup {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LedgerBackup.self, from: data)
    }

    func testFullBackupRoundTripPreservesSchedulesBudgetsAndDeletedOccurrenceHistory() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        try model.save(entry(merchant: "=Original text 🍎"))
        let rule = RecurringExpense(merchant: "Subscription", category: "Entertainment", account: "Card",
            amountCents: 1599, startDate: "01/31/2026", frequency: .monthly)
        try model.saveRecurring(rule)
        try model.postDueExpenses(through: "01/31/2026".dateParsed())
        let occurrence = try XCTUnwrap(model.transactions.first { $0.recurringID != nil })
        try model.delete([occurrence.id])
        let budgets = BudgetStore(inMemory: true)
        try budgets.setLimit(month: "2026-11", category: "Food & Dining", amount: "100.25", locale: Locale(identifier: "en_US"))
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let backup = try decode(LedgerExporter.json(model: model, budgets: budgets, at: timestamp))
        let snapshot = try model.exportSnapshot()
        XCTAssertEqual(backup.format, "ExpenseTracker")
        XCTAssertEqual(backup.version, 1)
        XCTAssertEqual(backup.currency, "USD")
        XCTAssertEqual(backup.exportedAt, timestamp)
        XCTAssertEqual(backup.ledger.version, 1)
        XCTAssertEqual(backup.ledger.transactions, snapshot.transactions)
        XCTAssertEqual(backup.ledger.recurringExpenses, snapshot.recurringExpenses)
        XCTAssertEqual(backup.ledger.postedOccurrences, snapshot.postedOccurrences)
        XCTAssertEqual(backup.budgets, try budgets.exportBudgets())
        XCTAssertEqual(backup.ledger.transactions[0].merchant, "=Original text 🍎", "JSON is full-fidelity, unlike spreadsheet text protection")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try JSONEncoder().encode(backup.ledger).write(to: url)
        let reconstructed = TransactionListViewModel(fetchOnInit: false, storageURL: url)
        XCTAssertNil(reconstructed.storageError)
        XCTAssertEqual(try reconstructed.postDueExpenses(through: "01/31/2026".dateParsed()), 0)
        XCTAssertEqual(reconstructed.transactions.count, 1, "Deleted occurrence history must survive the archive")
        XCTAssertEqual(try reconstructed.postDueExpenses(through: "02/28/2026".dateParsed()), 1)
        XCTAssertEqual(reconstructed.transactions.last?.recurringID, rule.id)
    }

    func testExportsDoNotMutateSourceFilesOrPostFutureExpenses() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledgerURL = directory.appendingPathComponent("transactions.json")
        let budgetsURL = directory.appendingPathComponent("budgets.json")
        let model = TransactionListViewModel(fetchOnInit: false, storageURL: ledgerURL)
        try model.save(entry())
        let rule = RecurringExpense(merchant: "Future", category: "Other", account: "Cash", amountCents: 100, startDate: "01/01/2099", frequency: .weekly)
        try model.saveRecurring(rule)
        let budgets = BudgetStore(inMemory: true, storageURL: budgetsURL)
        try budgets.setLimit(month: "2026-11", category: "Other", amount: "10", locale: Locale(identifier: "en_US"))
        let originalLedger = try Data(contentsOf: ledgerURL)
        let originalBudgets = try Data(contentsOf: budgetsURL)
        _ = try LedgerExporter.json(model: model, budgets: budgets)
        _ = try LedgerExporter.csv(model: model)
        XCTAssertEqual(try Data(contentsOf: ledgerURL), originalLedger)
        XCTAssertEqual(try Data(contentsOf: budgetsURL), originalBudgets)
        XCTAssertEqual(model.transactions.count, 1)
        XCTAssertEqual(model.recurringExpenses[0].nextIndex, 0)
    }

    func testCSVQuotesUnicodeCommasQuotesAndMultilineText() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        try model.save(entry(merchant: "Café, \"beans\"\r\n🍎"))
        let csv = String(decoding: try LedgerExporter.csv(model: model), as: UTF8.self)
        XCTAssertTrue(csv.contains("\"Café, \"\"beans\"\"\r\n🍎\""))
        XCTAssertTrue(csv.contains("\"2026-11-15\""))
        XCTAssertTrue(csv.contains("\"12.34\",\"-12.34\""))
        XCTAssertTrue(csv.hasSuffix("\r\n"))
    }

    func testCSVProtectsUserTextButPreservesTrustedNegativeAmounts() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        try model.save(entry(merchant: "=1+1", category: "+Food", account: " \t@SUM(1)", institution: "-Bank", type: "\r\n=FORMULA"))
        let csv = String(decoding: try LedgerExporter.csv(model: model), as: UTF8.self)
        for protected in ["'=1+1", "'+Food", "' \t@SUM(1)", "'-Bank", "'\r\n=FORMULA"] {
            XCTAssertTrue(csv.contains("\"" + protected + "\""), protected)
        }
        XCTAssertTrue(csv.contains("\"-12.34\""))
        XCTAssertFalse(csv.contains("\"'-12.34\""))
    }

    func testCSVStableDateIDOrderingAndIncomePrecision() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        try model.save(entry(id: 3, date: "12/01/2026", merchant: "Last", amount: 0.01))
        try model.save(entry(id: 2, merchant: "Second", amount: 1234.50, expense: false))
        try model.save(entry(id: 1, merchant: "First"))
        let csv = String(decoding: try LedgerExporter.csv(model: model), as: UTF8.self)
        let rows = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(rows.count, 5)
        XCTAssertTrue(rows[1].hasPrefix("\"1\",\"2026-11-15\",\"First\""))
        XCTAssertTrue(rows[2].hasPrefix("\"2\",\"2026-11-15\",\"Second\""))
        XCTAssertTrue(rows[2].contains("\"1234.50\",\"1234.50\""))
        XCTAssertTrue(rows[3].contains("\"0.01\",\"-0.01\""))
        XCTAssertEqual(try LedgerExporter.csv(model: model), try LedgerExporter.csv(model: model))
    }

    func testEmptyLedgerExportsExplicitHeadersAndCompleteEmptyBackup() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        let csv = String(decoding: try LedgerExporter.csv(model: model), as: UTF8.self)
        XCTAssertEqual(csv, LedgerExporter.csvHeaders.map { "\"" + $0 + "\"" }.joined(separator: ",") + "\r\n")
        let backup = try decode(LedgerExporter.json(model: model, budgets: BudgetStore(inMemory: true)))
        XCTAssertTrue(backup.ledger.transactions.isEmpty)
        XCTAssertTrue(backup.ledger.recurringExpenses.isEmpty)
        XCTAssertTrue(backup.ledger.postedOccurrences.isEmpty)
        XCTAssertTrue(backup.budgets.isEmpty)
    }

    func testUnreadableSourcesBlockFullBackupButBadBudgetsDoNotBlockCSV() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ledgerURL = directory.appendingPathComponent("transactions.json")
        let budgetsURL = directory.appendingPathComponent("budgets.json")
        let bad = Data("corrupt source".utf8)
        try bad.write(to: ledgerURL); try bad.write(to: budgetsURL)
        let unreadable = TransactionListViewModel(fetchOnInit: false, storageURL: ledgerURL)
        let badBudgets = BudgetStore(inMemory: true, storageURL: budgetsURL)
        XCTAssertThrowsError(try LedgerExporter.json(model: unreadable, budgets: BudgetStore(inMemory: true)))
        XCTAssertThrowsError(try LedgerExporter.csv(model: unreadable))
        let healthy = TransactionListViewModel(fetchOnInit: false)
        try healthy.save(entry())
        XCTAssertThrowsError(try LedgerExporter.json(model: healthy, budgets: badBudgets))
        XCTAssertNoThrow(try LedgerExporter.csv(model: healthy))
        XCTAssertEqual(try Data(contentsOf: ledgerURL), bad)
        XCTAssertEqual(try Data(contentsOf: budgetsURL), bad)
    }

    func testInvalidInMemoryEntriesCannotBeExportedAsHealthyBackup() throws {
        let model = TransactionListViewModel(fetchOnInit: false)
        model.transactions = [entry(), entry()]
        XCTAssertThrowsError(try LedgerExporter.csv(model: model))
        XCTAssertThrowsError(try LedgerExporter.json(model: model, budgets: BudgetStore(inMemory: true)))
        model.transactions = [entry(amount: -1)]
        XCTAssertThrowsError(try LedgerExporter.csv(model: model))
    }
}
