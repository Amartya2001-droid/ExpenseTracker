import SwiftUI
import UniformTypeIdentifiers

/// The same immutable bytes are previewed and handed to the system exporter.
struct PreparedLedgerExport: Identifiable {
    let id = UUID()
    let data: Data
    let contentType: UTType
    let filename: String
    var previewText: String { String(decoding: data.prefix(20_000), as: UTF8.self) }
    var previewIsShortened: Bool { data.count > 20_000 }
}

struct BackupExportView: View {
    @ObservedObject var model: TransactionListViewModel
    @StateObject private var budgets = BudgetStore()
    @State private var prepared: PreparedLedgerExport?
    @State private var errorMessage: String?

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
                Text("Includes transactions, recurring schedules and posting/deletion history, plus all category budgets. Review the preview before saving. Restore/import is not available in this app yet.").font(.caption)
            }
            Section("Spreadsheet Export") {
                Button("Export CSV") { prepare(json: false) }.disabled(model.storageError != nil)
                Text("Transactions only, for spreadsheets. Formula-like text is prefixed with an apostrophe; JSON keeps the original text. CSV cannot replace a full backup.").font(.caption)
            }
            Section("Choose Where to Save") {
                Text("Exported files are unencrypted and include financial details and account labels. Choose a destination you trust. The app does not upload files automatically. Generating an export does not change the ledger; normal foreground schedule posting still applies.").font(.caption)
            }
        }
        .navigationTitle("Backup & Export")
        .sheet(item: $prepared) { LedgerExportPreview(export: $0) }
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
            let filename = "ExpenseTracker-" + (json ? "backup-" : "transactions-") + formatter.string(from: Date())
            prepared = PreparedLedgerExport(data: data, contentType: json ? .json : .commaSeparatedText, filename: filename)
        } catch { errorMessage = error.localizedDescription }
    }
}

struct LedgerExportPreview: View {
    let export: PreparedLedgerExport
    @Environment(\.dismiss) private var dismiss
    @State private var showingExporter = false
    @State private var errorMessage: String?
    @State private var feedback: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(export.contentType == .json ? "Full JSON Backup" : "Transaction CSV").font(.headline)
                    Text(export.filename).font(.caption).foregroundStyle(.secondary)
                    Text("Review your data, then choose Save to Files. Cancel Preview returns without saving a file.").font(.subheadline)
                    if export.previewIsShortened { Text("Preview is shortened; the saved file includes all data.").font(.caption) }
                    if let feedback { Text(feedback).accessibilityIdentifier("exportFeedback") }
                    Text(export.previewText).font(.system(.caption, design: .monospaced))
                        .accessibilityIdentifier("exportPreviewText")
                }.padding().frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Export Preview").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel Preview") { dismiss() }.accessibilityIdentifier("cancelExportPreview")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save to Files") { showingExporter = true }.accessibilityIdentifier("saveExportToFiles")
                }
            }
            .fileExporter(isPresented: $showingExporter, document: LedgerExportDocument(data: export.data),
                          contentType: export.contentType, defaultFilename: export.filename) { result in
                switch result {
                case .success: feedback = "Export saved to your chosen location."
                case .failure(let error):
                    if (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSUserCancelledError {
                        feedback = "Files save cancelled."
                    } else { errorMessage = error.localizedDescription }
                }
            }
            .alert("Could Not Export", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}
