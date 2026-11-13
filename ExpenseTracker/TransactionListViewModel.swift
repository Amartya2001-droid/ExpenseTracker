import Foundation
import Combine

/// Owns the local ledger. A failed write never changes the in-memory balance.
final class TransactionListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var storageError: String?
    private let storageURL: URL?
    private var loadFailed = false

    init(fetchOnInit: Bool = true, storageURL: URL? = nil) {
        self.storageURL = storageURL ?? (fetchOnInit && !ProcessInfo.processInfo.arguments.contains("--uitesting") ? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("transactions.json") : nil)
        guard let url = self.storageURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let saved = try JSONDecoder().decode([Transaction].self, from: Data(contentsOf: url))
            guard Set(saved.map(\.id)).count == saved.count else { throw LedgerError.invalidData }
            for transaction in saved { try validate(transaction) }
            transactions = saved
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
        guard transaction.id > 0, transaction.id < Int.max,
              !transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !transaction.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              transaction.amount.isFinite, transaction.amount > 0, transaction.amount <= 999_999_999.99,
              abs(transaction.amount * 100 - (transaction.amount * 100).rounded()) < 0.0001,
              transaction.date.validTransactionDate != nil else { throw LedgerError.invalidData }
    }

    private func persist(_ updated: [Transaction]) throws {
        guard !loadFailed else { throw LedgerError.unreadableLedger }
        if let url = storageURL {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(updated).write(to: url, options: [.atomic, .completeFileProtection])
        }
        transactions = updated
        storageError = nil
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
