import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Full-fidelity archive. CSV is deliberately a separate, transaction-only representation.
struct LedgerBackup: Codable {
    let format: String
    let version: Int
    let currency: String
    let exportedAt: Date
    let ledger: LedgerSnapshot
    let budgets: [CategoryBudget]
}

enum LedgerExporter {
    static func json(model: TransactionListViewModel, budgets: BudgetStore, at date: Date = Date()) throws -> Data {
        let backup = LedgerBackup(format: "ExpenseTracker", version: 1, currency: "USD", exportedAt: date,
            ledger: try model.exportSnapshot(), budgets: try budgets.exportBudgets())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static let csvHeaders = ["id", "date", "merchant", "category", "account", "institution", "amount_usd",
        "signed_amount_usd", "type", "is_pending", "is_transfer", "is_expense", "is_cash_purchase", "recurring_id"]

    static func csv(model: TransactionListViewModel) throws -> Data {
        let snapshot = try model.exportSnapshot()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        var rows = [csvHeaders.map { cell($0) }.joined(separator: ",")]
        let sorted = snapshot.transactions.sorted { $0.parsedDate == $1.parsedDate ? $0.id < $1.id : $0.parsedDate < $1.parsedDate }
        for transaction in sorted {
            let values = [cell(String(transaction.id), protectText: false), cell(formatter.string(from: transaction.parsedDate)),
                cell(transaction.merchant), cell(transaction.category), cell(transaction.account), cell(transaction.institution),
                cell(money(transaction.amount), protectText: false), cell(money(transaction.signedAmount), protectText: false),
                cell(transaction.type), cell(String(transaction.isPending)), cell(String(transaction.isTransfer)),
                cell(String(transaction.isExpense)), cell(String(transaction.isCashPurchase)), cell(transaction.recurringID ?? "")]
            rows.append(values.joined(separator: ","))
        }
        return Data((rows.joined(separator: "\r\n") + "\r\n").utf8)
    }

    private static func money(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func cell(_ text: String, protectText: Bool = true) -> String {
        let ignored = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        let first = text.unicodeScalars.first { !ignored.contains($0) }
        let dangerous = first.map { "=+-@".unicodeScalars.contains($0) } ?? false
        let leadingControl = text.first.map { $0 == "\t" || $0 == "\r" || $0 == "\n" } ?? false
        let safe = protectText && (dangerous || leadingControl) ? "'" + text : text
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

struct LedgerExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
