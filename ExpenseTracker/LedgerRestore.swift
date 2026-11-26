import Foundation

enum RestoreError: LocalizedError {
    case invalid(String), tooLarge, confirmationRequired, stale, storageMismatch
    var errorDescription: String? {
        switch self {
        case .invalid(let message): return "Invalid backup: " + message
        case .tooLarge: return "Backup exceeds the 5 MiB or 20,000-record import limit."
        case .confirmationRequired: return "Explicit replacement confirmation is required. No data was changed."
        case .stale: return "Current data changed. Cancel and review a new restore preview before replacing it."
        case .storageMismatch: return "Ledger and budgets must use the same app snapshot storage."
        }
    }
}

struct AppSnapshot: Codable, Equatable {
    var version = 1
    var ledger: LedgerSnapshot
    var budgets: [CategoryBudget]
}

/// A single durable commit point. Legacy files are retained and never half-replaced.
enum AtomicAppState {
    static var defaultURL: URL? { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("restored-app-state.json") }
    static func read(_ url: URL) throws -> AppSnapshot {
        let state = try JSONDecoder().decode(AppSnapshot.self, from: Data(contentsOf: url))
        guard state.version == 1 else { throw RestoreError.invalid("unsupported app snapshot version") }
        try RestoreValidation.content(state.ledger, budgets: state.budgets, checkHistory: false)
        return state
    }
    static func write(_ state: AppSnapshot, to url: URL) throws {
        try RestoreValidation.content(state.ledger, budgets: state.budgets, checkHistory: false)
        let data = try JSONEncoder().encode(state)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}

enum RestoreValidation {
    static let maxBytes = 5 * 1024 * 1024
    static let maxRecords = 20_000

    static func readFile(_ url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while let chunk = try handle.read(upToCount: min(65_536, maxBytes + 1 - data.count)), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= maxBytes else { throw RestoreError.tooLarge }
        }
        return data
    }

    private static func object(_ value: Any, required: Set<String>, optional: Set<String> = []) throws -> [String: Any] {
        guard let object = value as? [String: Any], required.isSubset(of: Set(object.keys)),
              Set(object.keys).isSubset(of: required.union(optional)) else { throw RestoreError.invalid("missing or unknown schema fields") }
        return object
    }

    static func decode(_ data: Data) throws -> LedgerBackup {
        guard data.count <= maxBytes else { throw RestoreError.tooLarge }
        let raw = try object(JSONSerialization.jsonObject(with: data), required: ["format", "version", "currency", "exportedAt", "ledger", "budgets"])
        guard let rawLedger = raw["ledger"] else { throw RestoreError.invalid("missing ledger") }
        let ledger = try object(rawLedger, required: ["version", "transactions", "recurringExpenses", "postedOccurrences"])
        guard let transactions = ledger["transactions"] as? [Any], let rules = ledger["recurringExpenses"] as? [Any],
              let history = ledger["postedOccurrences"] as? [String], let budgets = raw["budgets"] as? [Any] else {
            throw RestoreError.invalid("record collections have the wrong type")
        }
        guard transactions.count + rules.count + history.count + budgets.count <= maxRecords else { throw RestoreError.tooLarge }
        guard Set(history).count == history.count else { throw RestoreError.invalid("duplicate posting history") }
        for value in transactions {
            _ = try object(value, required: ["id", "date", "institution", "account", "merchant", "amount", "type", "categoryId", "category", "isPending", "isTransfer", "isExpense", "isCashPurchase"], optional: ["recurringID"])
        }
        for value in rules { _ = try object(value, required: ["id", "merchant", "category", "account", "amountCents", "startDate", "frequency", "nextIndex"]) }
        for value in budgets { _ = try object(value, required: ["month", "category", "limitCents"]) }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(LedgerBackup.self, from: data)
        guard backup.format == "ExpenseTracker", backup.version == 1, backup.currency == "USD" else { throw RestoreError.invalid("unsupported format, version or currency") }
        try content(backup.ledger, budgets: backup.budgets, checkHistory: true)
        return backup
    }

    static func content(_ snapshot: LedgerSnapshot, budgets: [CategoryBudget], checkHistory: Bool) throws {
        guard snapshot.version == 1, Set(snapshot.transactions.map(\.id)).count == snapshot.transactions.count,
              Set(snapshot.recurringExpenses.map(\.id)).count == snapshot.recurringExpenses.count else { throw RestoreError.invalid("version or duplicate record IDs") }
        for transaction in snapshot.transactions { try TransactionListViewModel.validateTransaction(transaction) }
        for rule in snapshot.recurringExpenses { try TransactionListViewModel.validateRecurring(rule) }
        var budgetKeys = Set<String>()
        for budget in budgets {
            try BudgetStore.validateBudget(budget)
            guard budgetKeys.insert(budget.month + ":" + budget.category).inserted else { throw RestoreError.invalid("duplicate budget") }
        }
        var historyCounts: [String: Int] = [:]
        for key in snapshot.postedOccurrences {
            let parts = key.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count == 2, UUID(uuidString: String(parts[0])) != nil, String(parts[1]).validTransactionDate != nil else {
                throw RestoreError.invalid("malformed posting history")
            }
            historyCounts[String(parts[0]), default: 0] += 1
        }
        if checkHistory {
            for transaction in snapshot.transactions {
                if let source = transaction.recurringID, historyCounts[source, default: 0] == 0 { throw RestoreError.invalid("recurring entry has no posting history") }
            }
            for rule in snapshot.recurringExpenses {
                guard rule.nextIndex <= historyCounts[rule.id, default: 0] else { throw RestoreError.invalid("schedule checkpoint lacks posting history") }
                for index in 0..<rule.nextIndex {
                    guard let date = rule.occurrence(at: index), snapshot.postedOccurrences.contains(rule.id + "|" + RecurringExpense.dateString(date)) else {
                        throw RestoreError.invalid("schedule checkpoint is inconsistent")
                    }
                }
            }
        }
    }
}

struct RestoreChange: Identifiable {
    let id: String
    let title: String
    let before: String?
    let after: String?
}

struct RestoreDraft: Identifiable {
    let id = UUID()
    let backup: LedgerBackup
    let before: LedgerSnapshot
    let beforeBudgets: [CategoryBudget]
    let ledgerRevision: Data?
    let budgetRevision: Data?
    let changes: [RestoreChange]
}

enum LedgerRestorer {
    static func prepare(_ data: Data, model: TransactionListViewModel, budgets: BudgetStore) throws -> RestoreDraft {
        let backup = try RestoreValidation.decode(data)
        let before = try model.exportSnapshot()
        let beforeBudgets = try budgets.exportBudgets()
        var changes = [RestoreChange]()
        changes += try diff(before.transactions, backup.ledger.transactions, kind: "transaction", key: { String($0.id) }, name: { $0.merchant })
        changes += try diff(before.recurringExpenses, backup.ledger.recurringExpenses, kind: "schedule", key: { $0.id }, name: { $0.merchant })
        changes += try diff(beforeBudgets, backup.budgets, kind: "budget", key: { $0.month + ":" + $0.category }, name: { $0.category })
        let added = backup.ledger.postedOccurrences.subtracting(before.postedOccurrences)
        let removed = before.postedOccurrences.subtracting(backup.ledger.postedOccurrences)
        for key in added.sorted() { changes.append(RestoreChange(id: "history-" + key, title: "Add posting history " + key, before: nil, after: key)) }
        for key in removed.sorted() { changes.append(RestoreChange(id: "history-" + key, title: "Remove posting history " + key, before: key, after: nil)) }
        return RestoreDraft(backup: backup, before: before, beforeBudgets: beforeBudgets,
            ledgerRevision: try model.storageRevision(), budgetRevision: try budgets.storageRevision(), changes: changes)
    }

    private static func diff<T: Encodable & Equatable>(_ old: [T], _ new: [T], kind: String, key: (T) -> String, name: (T) -> String) throws -> [RestoreChange] {
        let oldMap = Dictionary(uniqueKeysWithValues: old.map { (key($0), $0) })
        let newMap = Dictionary(uniqueKeysWithValues: new.map { (key($0), $0) })
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try Set(oldMap.keys).union(newMap.keys).sorted().compactMap { id in
            let before = oldMap[id]; let after = newMap[id]
            guard before != after else { return nil }
            let action = before == nil ? "Add" : (after == nil ? "Remove" : "Change")
            let label = after.map(name) ?? before.map(name) ?? id
            return RestoreChange(id: kind + "-" + id, title: action + " " + kind + " " + id + " — " + label,
                before: try before.map { String(decoding: try encoder.encode($0), as: UTF8.self) },
                after: try after.map { String(decoding: try encoder.encode($0), as: UTF8.self) })
        }
    }

    static func commit(_ draft: RestoreDraft, confirmed: Bool, model: TransactionListViewModel, budgets: BudgetStore) throws {
        guard confirmed else { throw RestoreError.confirmationRequired }
        guard model.unifiedURL == budgets.unifiedURL else { throw RestoreError.storageMismatch }
        let current = try model.exportSnapshot()
        let currentBudgets = try budgets.exportBudgets()
        let ledgerRevision = try model.storageRevision()
        let budgetRevision = try budgets.storageRevision()
        guard current == draft.before, currentBudgets == draft.beforeBudgets,
              ledgerRevision == draft.ledgerRevision, budgetRevision == draft.budgetRevision else { throw RestoreError.stale }
        try RestoreValidation.content(draft.backup.ledger, budgets: draft.backup.budgets, checkHistory: true)
        if let url = model.unifiedURL { try AtomicAppState.write(AppSnapshot(ledger: draft.backup.ledger, budgets: draft.backup.budgets), to: url) }
        model.adoptRestored(draft.backup.ledger)
        budgets.adoptRestored(draft.backup.budgets)
    }
}
