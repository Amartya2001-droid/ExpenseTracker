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
