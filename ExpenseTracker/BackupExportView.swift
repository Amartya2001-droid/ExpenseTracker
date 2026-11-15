import SwiftUI
import UniformTypeIdentifiers

struct BackupExportView: View {
    @ObservedObject var model: TransactionListViewModel
    @StateObject private var budgets = BudgetStore()
    @State private var document: LedgerExportDocument?
    @State private var contentType: UTType = .json
    @State private var filename = "ExpenseTracker-backup"
    @State private var showingExporter = false
    @State private var errorMessage: String?
    @State private var feedback: String?

    var body: some View {
        List {
            Section("Current Data") {
                Text("Transactions: \(model.transactions.count)")
                Text("Schedules: \(model.recurringExpenses.count)")
                if budgets.storageError == nil { Text("Category limits: \(budgets.budgets.count)") }
                if let message = model.storageError { Text(message).foregroundStyle(.red) }
                if let message = budgets.storageError {
                    Text(message).foregroundStyle(.red)
                    Text("Full JSON backup is unavailable; a healthy transaction ledger can still be exported as CSV.").font(.caption)
                }
            }
            Section("Full Backup") {
                Button("Export JSON Backup") { prepare(json: true) }
                    .disabled(model.storageError != nil || budgets.storageError != nil)
                Text("Includes transactions, recurring schedules and posting/deletion history, plus all category budgets. Versioned JSON preserves the original data. Restore/import is not available in this app yet.").font(.caption)
            }
            Section("Spreadsheet Export") {
                Button("Export CSV") { prepare(json: false) }.disabled(model.storageError != nil)
                Text("Transactions only, ordered by date and ID. UTF-8 CSV uses Gregorian dates and USD decimals. Formula-like text is prefixed with an apostrophe for spreadsheet safety; JSON keeps the original text. CSV cannot replace a full backup.").font(.caption)
            }
            Section("Choose Where to Save") {
                Text("Exported files are unencrypted and include financial details and account labels. Choose a destination you trust. The app does not upload files automatically. Generating an export does not change the ledger; normal foreground schedule posting still applies.").font(.caption)
                if let feedback { Text(feedback).accessibilityIdentifier("exportFeedback") }
            }
        }
        .navigationTitle("Backup & Export")
        .fileExporter(isPresented: $showingExporter, document: document, contentType: contentType, defaultFilename: filename) { result in
            switch result {
            case .success: feedback = "Export saved to your chosen location."
            case .failure(let error):
                if (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSUserCancelledError {
                    feedback = "Export cancelled. Your ledger is unchanged."
                } else { errorMessage = error.localizedDescription }
            }
            document = nil
        }
        .alert("Could Not Export", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func prepare(json: Bool) {
        do {
            let data: Data
            if json { data = try LedgerExporter.json(model: model, budgets: budgets) }
            else { data = try LedgerExporter.csv(model: model) }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            filename = "ExpenseTracker-" + (json ? "backup-" : "transactions-") + formatter.string(from: Date())
            contentType = json ? .json : .commaSeparatedText
            document = LedgerExportDocument(data: data)
            feedback = nil
            showingExporter = true
        } catch { errorMessage = error.localizedDescription }
    }
}
