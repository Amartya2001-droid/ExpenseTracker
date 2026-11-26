import SwiftUI
import UIKit

/// Plain JSON entry is a production alternative to Files, not a test-only importer.
struct BackupJSONEditor: UIViewRepresentable {
    @Binding var text: String
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        view.autocorrectionType = .no; view.autocapitalizationType = .none
        view.smartQuotesType = .no; view.smartDashesType = .no; view.smartInsertDeleteType = .no
        view.keyboardType = .asciiCapable
        view.accessibilityIdentifier = "backupJSONInput"
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text { view.text = text }
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BackupJSONEditor
        init(_ parent: BackupJSONEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }
}

struct RestoreJSONInputView: View {
    @ObservedObject var model: TransactionListViewModel
    @ObservedObject var budgets: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var draft: RestoreDraft?
    @State private var errorMessage: String?
    var body: some View {
        Form {
            Section {
                Text("Current transactions: \(model.transactions.count)")
                Text("Current schedules: \(model.recurringExpenses.count)")
                Text("Current category limits: \(budgets.budgets.count)")
            }
            Section("Paste the Complete JSON Backup") {
                BackupJSONEditor(text: $text).frame(minHeight: 240)
                Text("Validation and preview do not change your data. Replacement requires a separate explicit confirmation. CSV is not supported.").font(.caption)
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("restoreValidationError") }
        }
        .navigationTitle("Backup JSON")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() }.accessibilityIdentifier("closeBackupJSONInput") }
            ToolbarItem(placement: .confirmationAction) {
                Button("Validate Backup") {
                    do { draft = try LedgerRestorer.prepare(Data(text.utf8), model: model, budgets: budgets); errorMessage = nil }
                    catch { errorMessage = error.localizedDescription }
                }.accessibilityIdentifier("validateBackupJSON")
            }
        }
        .sheet(item: $draft) { RestorePreviewView(draft: $0, model: model, budgets: budgets) }
    }
}

struct RestorePreviewView: View {
    let draft: RestoreDraft
    @ObservedObject var model: TransactionListViewModel
    @ObservedObject var budgets: BudgetStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Full Replacement — Current → Backup") {
                    Text("Transactions: \(draft.before.transactions.count) → \(draft.backup.ledger.transactions.count)")
                    Text("Schedules: \(draft.before.recurringExpenses.count) → \(draft.backup.ledger.recurringExpenses.count)")
                    Text("Category limits: \(draft.beforeBudgets.count) → \(draft.backup.budgets.count)")
                    Text("Posting history: \(draft.before.postedOccurrences.count) → \(draft.backup.ledger.postedOccurrences.count)")
                    Text("Current transactions: \(model.transactions.count)").font(.caption)
                    Text("This replaces all app data, not a merge. Export a current backup first. Nothing is replaced until you confirm. Restoring a schedule preserves its saved checkpoint; normal foreground posting resumes afterward.").font(.caption)
                }
                Section("Every Added, Removed or Changed Record") {
                    if draft.changes.isEmpty { Text("No record changes.") }
                    ForEach(draft.changes) { change in
                        DisclosureGroup {
                            if let before = change.before {
                                Text("Before").font(.headline)
                                Text(before).font(.system(.caption, design: .monospaced)).accessibilityIdentifier("restoreBefore-" + change.id)
                            }
                            if let after = change.after {
                                Text("After").font(.headline)
                                Text(after).font(.system(.caption, design: .monospaced)).accessibilityIdentifier("restoreAfter-" + change.id)
                            }
                        } label: { Text(change.title).accessibilityIdentifier("restoreChange-" + change.id) }
                    }
                }
                if let errorMessage { Section { Text(errorMessage).foregroundStyle(.red).accessibilityIdentifier("restoreCommitError") } }
            }
            .navigationTitle("Restore Preview").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel Restore") { dismiss() }.accessibilityIdentifier("cancelRestorePreview") }
                ToolbarItem(placement: .confirmationAction) { Button("Replace…") { confirming = true }.accessibilityIdentifier("reviewRestoreReplacement") }
            }
            .confirmationDialog("Replace ledger, schedules and budgets?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Replace Ledger and Budgets", role: .destructive) {
                    do { try LedgerRestorer.commit(draft, confirmed: true, model: model, budgets: budgets); dismiss() }
                    catch { errorMessage = error.localizedDescription }
                }
                Button("Cancel", role: .cancel) { }
            } message: { Text("All current data is replaced by the reviewed backup. This cannot be undone in the app. Cancel makes no changes.") }
        }
    }
}
