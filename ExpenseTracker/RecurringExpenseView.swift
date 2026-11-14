import SwiftUI

struct RecurringExpenseView: View {
    @ObservedObject var model: TransactionListViewModel
    @State private var adding = false
    @State private var editing: RecurringExpense?
    @State private var errorMessage: String?
    @State private var feedback: String?

    var body: some View {
        List {
            Section {
                Text("Due expenses are added locally when the app opens, returns to the foreground, or you tap Post Due. This does not make payments or run in the background.").font(.caption)
                Button("Post Due") { postDue() }
                if let feedback { Text(feedback).accessibilityIdentifier("recurringFeedback") }
                if let message = model.storageError { Text(message).foregroundStyle(.red) }
            }
            Section("Schedules") {
                if model.recurringExpenses.isEmpty { Text("No recurring expenses. Add a weekly or monthly schedule.").foregroundStyle(.secondary) }
                ForEach(model.recurringExpenses) { rule in
                    Button { editing = rule } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(rule.merchant).font(.headline)
                            Text((Double(rule.amountCents) / 100).formatted(.currency(code: "USD")) + " · " + rule.frequency.rawValue.capitalized)
                            if let next = rule.occurrence(at: rule.nextIndex) {
                                Text("Next: " + next.formatted(date: .abbreviated, time: .omitted))
                            } else { Text("Schedule complete") }
                        }
                    }.buttonStyle(.plain)
                    .swipeActions {
                        Button("Delete Schedule", role: .destructive) {
                            do { try model.deleteRecurring(rule.id) } catch { errorMessage = error.localizedDescription }
                        }
                    }
                }
            }
            Section {
                Text("Tap a schedule to edit future postings. Posted ledger entries stay unchanged and can be edited/deleted in See All. Deleting a schedule keeps its history; deleting a posted occurrence does not recreate it. Catch-up handles 500 schedule steps per action; tap Post Due again for a longer backlog.").font(.caption)
            }
        }
        .navigationTitle("Recurring Expenses")
        .toolbar { Button("Add Schedule") { adding = true } }
        .sheet(isPresented: $adding, onDismiss: { postDue() }) { RecurringExpenseEditor(model: model) }
        .sheet(item: $editing, onDismiss: { postDue() }) { RecurringExpenseEditor(model: model, existing: $0) }
        .alert("Recurring Expense Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func postDue() {
        do { feedback = "Posted \(try model.postDueExpenses()) due expenses. Remaining due schedules can be processed with Post Due." }
        catch { errorMessage = error.localizedDescription }
    }
}

struct RecurringExpenseEditor: View {
    @ObservedObject var model: TransactionListViewModel
    var existing: RecurringExpense?
    @Environment(\.dismiss) private var dismiss
    @State private var merchant = ""
    @State private var amount = ""
    @State private var category = "Food & Dining"
    @State private var account = "Cash"
    @State private var date = Date()
    @State private var frequency = RecurringExpense.Frequency.monthly
    @State private var errorMessage: String?

    private var categories: [String] { Array(Set(BudgetStore.categories + model.transactions.map(\.category) + [category])).sorted() }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Recurring description", text: $merchant)
                TextField("Recurring amount (USD)", text: $amount).keyboardType(.decimalPad)
                Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }
                TextField("Account", text: $account)
                Picker("Repeat", selection: $frequency) {
                    ForEach(RecurringExpense.Frequency.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                DatePicker(existing == nil ? "First date" : "Next date", selection: $date, displayedComponents: .date)
                    .environment(\.calendar, RecurringExpense.calendar)
                Text("Monthly schedules use this day of the month, clamping to shorter month ends without drifting. Past first dates catch up into the ledger. When editing, choose today or a future next date; posted entries are not changed.").font(.caption)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle(existing == nil ? "Add Schedule" : "Edit Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save Schedule") { save() } }
            }
            .onAppear {
                guard let rule = existing else { return }
                merchant = rule.merchant
                amount = (Double(rule.amountCents) / 100).formatted(.number.grouping(.never).precision(.fractionLength(2)))
                category = rule.category; account = rule.account; frequency = rule.frequency
                date = max(rule.occurrence(at: rule.nextIndex) ?? Date(), RecurringExpense.calendar.startOfDay(for: Date()))
            }
        }
    }

    private func save() {
        do {
            let value = try Transaction.parseAmount(amount)
            let rule = RecurringExpense(id: existing?.id ?? UUID().uuidString,
                merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines), category: category,
                account: account.trimmingCharacters(in: .whitespacesAndNewlines), amountCents: Int64((value * 100).rounded()),
                startDate: RecurringExpense.dateString(date), frequency: frequency)
            try model.saveRecurring(rule)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
