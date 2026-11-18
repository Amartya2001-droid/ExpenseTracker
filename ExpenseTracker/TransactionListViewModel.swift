import Foundation
import Combine

/// Owns the local ledger. A failed write never changes the in-memory balance.
final class TransactionListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var storageError: String?
    @Published private(set) var recurringExpenses: [RecurringExpense] = []
    private var postedOccurrences: Set<String> = []
    private let storageURL: URL?
    private var loadFailed = false

    init(fetchOnInit: Bool = true, storageURL: URL? = nil) {
        self.storageURL = storageURL ?? (fetchOnInit && !ProcessInfo.processInfo.arguments.contains("--uitesting") ? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("transactions.json") : nil)
        guard let url = self.storageURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let snapshot: LedgerSnapshot
            if let legacy = try? decoder.decode([Transaction].self, from: data) {
                snapshot = LedgerSnapshot(transactions: legacy, recurringExpenses: [], postedOccurrences: [])
            } else {
                snapshot = try decoder.decode(LedgerSnapshot.self, from: data)
            }
            guard snapshot.version == 1,
                  Set(snapshot.transactions.map(\.id)).count == snapshot.transactions.count,
                  Set(snapshot.recurringExpenses.map(\.id)).count == snapshot.recurringExpenses.count else { throw LedgerError.invalidData }
            for transaction in snapshot.transactions { try validate(transaction) }
            for rule in snapshot.recurringExpenses { try validateRecurring(rule) }
            for key in snapshot.postedOccurrences {
                let parts = key.split(separator: "|", omittingEmptySubsequences: false)
                guard parts.count == 2, UUID(uuidString: String(parts[0])) != nil,
                      String(parts[1]).validTransactionDate != nil else { throw LedgerError.invalidData }
            }
            transactions = snapshot.transactions
            recurringExpenses = snapshot.recurringExpenses
            postedOccurrences = snapshot.postedOccurrences
        } catch {
            loadFailed = true
            storageError = "Your saved ledger could not be read. It has been preserved. Restore a valid transactions.json backup before making changes."
        }
    }

    enum LedgerError: LocalizedError {
        case invalidData, unreadableLedger
        var errorDescription: String? {
            switch self {
            case .invalidData: return "Enter a merchant, category, valid date, and a positive amount with at most two decimal places (up to $999,999,999.99)."
            case .unreadableLedger: return "The saved ledger could not be read. Changes are disabled to protect it."
            }
        }
    }

    private func validate(_ transaction: Transaction) throws {
        guard (transaction.recurringID == nil || UUID(uuidString: transaction.recurringID ?? "") != nil),
              transaction.id > 0, transaction.id < Int.max,
              !transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !transaction.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              transaction.amount.isFinite, transaction.amount > 0, transaction.amount <= 999_999_999.99,
              abs(transaction.amount * 100 - (transaction.amount * 100).rounded()) < 0.0001,
              transaction.date.validTransactionDate != nil else { throw LedgerError.invalidData }
    }

    private func persist(_ updated: [Transaction], rules: [RecurringExpense]? = nil, posted: Set<String>? = nil) throws {
        guard !loadFailed else { throw LedgerError.unreadableLedger }
        if let url = storageURL {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let snapshot = LedgerSnapshot(transactions: updated, recurringExpenses: rules ?? recurringExpenses, postedOccurrences: posted ?? postedOccurrences)
            try JSONEncoder().encode(snapshot).write(to: url, options: [.atomic, .completeFileProtection])
        }
        transactions = updated
        recurringExpenses = rules ?? recurringExpenses
        postedOccurrences = posted ?? postedOccurrences
        storageError = nil
    }

    /// Capture a validated, full ledger without posting, writing, or changing checkpoints.
    func exportSnapshot() throws -> LedgerSnapshot {
        guard !loadFailed else { throw LedgerError.unreadableLedger }
        guard Set(transactions.map(\.id)).count == transactions.count else { throw LedgerError.invalidData }
        for transaction in transactions { try validate(transaction) }
        for rule in recurringExpenses { try validateRecurring(rule) }
        return LedgerSnapshot(transactions: transactions, recurringExpenses: recurringExpenses, postedOccurrences: postedOccurrences)
    }

    func save(_ transaction: Transaction) throws {
        try validate(transaction)
        var updated = transactions
        if let index = updated.firstIndex(where: { $0.id == transaction.id }) { updated[index] = transaction }
        else { updated.append(transaction) }
        try persist(updated)
    }

    func delete(_ ids: Set<Int>) throws { try persist(transactions.filter { !ids.contains($0.id) }) }

    func loadSampleData() throws {
        // Explicit opt-in, only on an empty ledger; never overwrite personal entries.
        guard transactions.isEmpty else { return }
        try persist(Transaction.all)
    }

    private func validateRecurring(_ rule: RecurringExpense) throws {
        guard UUID(uuidString: rule.id) != nil, !rule.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !rule.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              rule.amountCents > 0, rule.amountCents <= 99_999_999_999,
              rule.startDate.validTransactionDate != nil, (0...1_000_000).contains(rule.nextIndex) else {
            throw RecurringExpense.ScheduleError.invalid
        }
    }

    func saveRecurring(_ rule: RecurringExpense, today: Date = Date()) throws {
        try validateRecurring(rule)
        var updated = recurringExpenses
        if let index = updated.firstIndex(where: { $0.id == rule.id }) {
            guard let start = rule.startDate.validTransactionDate,
                  start >= RecurringExpense.calendar.startOfDay(for: today) else { throw RecurringExpense.ScheduleError.editInPast }
            var replacement = rule
            let previous = updated[index]
            if previous.frequency == rule.frequency,
               let next = previous.occurrence(at: previous.nextIndex),
               RecurringExpense.dateString(next) == rule.startDate {
                // Editing the amount on February's clamped date must retain January's day-31 anchor.
                replacement.startDate = previous.startDate
                replacement.nextIndex = previous.nextIndex
            } else { replacement.nextIndex = 0 }
            updated[index] = replacement
        } else {
            var replacement = rule
            replacement.nextIndex = 0
            updated.append(replacement)
        }
        try persist(transactions, rules: updated)
    }

    func deleteRecurring(_ id: String) throws {
        try persist(transactions, rules: recurringExpenses.filter { $0.id != id })
    }

    /// At most 500 schedule steps per call. Checkpoints and entries are committed together.
    @discardableResult
    func postDueExpenses(through today: Date = Date()) throws -> Int {
        guard !loadFailed else { throw LedgerError.unreadableLedger }
        var updated = transactions
        var rules = recurringExpenses
        var posted = postedOccurrences
        let cutoff = RecurringExpense.calendar.startOfDay(for: today)
        var steps = 0
        var count = 0
        var lastID = updated.map(\.id).max() ?? 0
        for index in rules.indices {
            while steps < 500, let due = rules[index].occurrence(at: rules[index].nextIndex), due <= cutoff {
                let rule = rules[index]
                let date = RecurringExpense.dateString(due)
                let key = rule.id + "|" + date
                if !posted.contains(key) {
                    guard lastID < Int.max - 1 else { throw RecurringExpense.ScheduleError.exhaustedIDs }
                    lastID += 1
                    let transaction = Transaction(id: lastID, date: date, institution: "Local", account: rule.account,
                        merchant: rule.merchant, amount: Double(rule.amountCents) / 100, type: "debit", categoryId: 0,
                        category: rule.category, isPending: false, isTransfer: false, isExpense: true,
                        isCashPurchase: rule.account.lowercased() == "cash", recurringID: rule.id)
                    try validate(transaction)
                    updated.append(transaction)
                    posted.insert(key)
                    count += 1
                }
                rules[index].nextIndex += 1
                steps += 1
            }
        }
        if steps > 0 { try persist(updated, rules: rules, posted: posted) }
        return count
    }

    var nextID: Int { (transactions.map(\.id).max() ?? 0) + 1 }

    func filteredTransactions(search: String = "", expensesOnly: Bool = false) -> [Transaction] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return transactions.filter {
            (!expensesOnly || $0.isExpense) && (query.isEmpty || "\($0.merchant) \($0.category) \($0.account)".localizedCaseInsensitiveContains(query))
        }.sorted { $0.parsedDate == $1.parsedDate ? $0.id > $1.id : $0.parsedDate > $1.parsedDate }
    }

    func groupTransactionsByMonth() -> [(key: String, value: [Transaction])] {
        let sorted = filteredTransactions()
        let keys = sorted.map(\.month).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return keys.map { key in (key, sorted.filter { $0.month == key }) }
    }

    func expenses(inMonth date: Date, calendar: Calendar = .current) -> Double {
        transactions.filter { $0.isExpense && calendar.isDate($0.parsedDate, equalTo: date, toGranularity: .month) }.reduce(0) { $0 + $1.amount }
    }

    func accumulateTransactions() -> [(String, Double)] {
        let today = Date()
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: today) else { return [] }
        var sum = 0.0
        var result: [(String, Double)] = []
        var current = interval.start
        while current <= today {
            sum += transactions.filter { $0.isExpense && calendar.isDate($0.parsedDate, inSameDayAs: current) }.reduce(0) { $0 + $1.amount }
            if sum > 0 { result.append((current.formatted(.dateTime.month(.twoDigits).day(.twoDigits)), sum)) }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    var totalExpenses: Double { transactions.filter(\.isExpense).reduce(0) { $0 + $1.amount } }
    var totalIncome: Double { transactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount } }
    var balance: Double { totalIncome - totalExpenses }
    var recentTransactions: [Transaction] { Array(filteredTransactions().prefix(5)) }
}

// Budget limits are independent of transactions and stored in integer USD cents.
struct CategoryBudget: Codable, Equatable {
    let month: String
    let category: String
    let limitCents: Int64
}

struct CategorySpending: Identifiable {
    var id: String { category }
    let category: String
    let spentCents: Int64
    let limitCents: Int64?
    var remainingCents: Int64? { limitCents.map { $0 - spentCents } }
    var progress: Double { guard let limit = limitCents else { return 0 }; return min(Double(spentCents) / Double(limit), 1) }
}

final class BudgetStore: ObservableObject {
    @Published private(set) var budgets: [CategoryBudget] = []
    @Published private(set) var storageError: String?
    private let storageURL: URL?
    private var loadFailed = false
    static let categories = ["Food & Dining", "Shopping", "Transport", "Housing", "Utilities", "Health", "Entertainment", "Other"]
    static var calendar: Calendar { Calendar(identifier: .gregorian) }

    static func monthKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    init(inMemory: Bool = false, storageURL: URL? = nil) {
        self.storageURL = storageURL ?? (inMemory || ProcessInfo.processInfo.arguments.contains("--uitesting") ? nil : FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("budgets.json"))
        guard let url = self.storageURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let saved = try JSONDecoder().decode([CategoryBudget].self, from: Data(contentsOf: url))
            var seen = Set<String>()
            for budget in saved {
                try Self.validate(budget)
                guard seen.insert(budget.month + ":" + budget.category).inserted else { throw BudgetError.invalid }
            }
            budgets = saved
        } catch {
            loadFailed = true
            storageError = "Saved budgets could not be read. The file is preserved and budget changes are blocked. Your transaction ledger is unchanged."
        }
    }

    enum BudgetError: LocalizedError {
        case invalid, unreadable
        var errorDescription: String? {
            switch self {
            case .invalid: return "Choose a category and a valid month, with a positive USD limit up to $999,999,999.99."
            case .unreadable: return "Budget changes are blocked because the saved file could not be read. Restore a valid budgets.json backup first."
            }
        }
    }

    private static func validate(_ budget: CategoryBudget) throws {
        guard budget.month.count == 7, budget.month.range(of: #"^(?!0000)[0-9]{4}-(0[1-9]|1[0-2])$"#, options: .regularExpression) != nil,
              !budget.category.isEmpty, budget.category == budget.category.trimmingCharacters(in: .whitespacesAndNewlines),
              budget.limitCents > 0, budget.limitCents <= 99_999_999_999 else { throw BudgetError.invalid }
    }

    private func persist(_ updated: [CategoryBudget]) throws {
        guard !loadFailed else { throw BudgetError.unreadable }
        if let url = storageURL {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: url, options: [.atomic, .completeFileProtection])
        }
        budgets = updated
    }

    func exportBudgets() throws -> [CategoryBudget] {
        guard !loadFailed else { throw BudgetError.unreadable }
        for budget in budgets { try Self.validate(budget) }
        return budgets.sorted { $0.month == $1.month ? $0.category < $1.category : $0.month < $1.month }
    }

    func setLimit(month: String, category: String, amount: String, locale: Locale = .current) throws {
        let parsed = try Transaction.parseAmount(amount, locale: locale)
        let budget = CategoryBudget(month: month, category: category.trimmingCharacters(in: .whitespacesAndNewlines), limitCents: Int64((parsed * 100).rounded()))
        try Self.validate(budget)
        var updated = budgets.filter { $0.month != month || $0.category != budget.category }
        updated.append(budget)
        try persist(updated)
    }

    func remove(month: String, category: String) throws {
        try persist(budgets.filter { $0.month != month || $0.category != category })
    }

    func insights(for month: String, transactions: [Transaction]) -> [CategorySpending] {
        // Sum each ledger amount in cents, rather than adding binary floating-point dollars.
        var spending: [String: Int64] = [:]
        for transaction in transactions where transaction.isExpense && !transaction.isTransfer {
            guard let date = transaction.date.validTransactionDate, Self.monthKey(for: date) == month,
                  transaction.amount.isFinite, transaction.amount > 0, transaction.amount <= 999_999_999.99 else { continue }
            let cents = Int64((transaction.amount * 100).rounded())
            let previous = spending[transaction.category, default: 0]
            let (sum, overflow) = previous.addingReportingOverflow(cents)
            spending[transaction.category] = overflow ? Int64.max : sum
        }
        let limits = Dictionary(uniqueKeysWithValues: budgets.filter { $0.month == month }.map { ($0.category, $0.limitCents) })
        return Set(spending.keys).union(limits.keys).map { category in
            CategorySpending(category: category, spentCents: spending[category, default: 0], limitCents: limits[category])
        }.sorted { $0.spentCents == $1.spentCents ? $0.category < $1.category : $0.spentCents > $1.spentCents }
    }
}
