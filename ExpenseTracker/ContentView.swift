import SwiftUI
import Charts

struct ContentView: View {
    @StateObject var viewModel = TransactionListViewModel()
    @State private var showingEntry = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Overview").font(.title2.bold())
                        Text(Date(), style: .date).foregroundStyle(.secondary)
                        Text("Stored on this device · USD").font(.caption).foregroundStyle(.secondary)
                    }.padding(.horizontal)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This Month").font(.headline)
                        Text(viewModel.expenses(inMonth: Date()), format: .currency(code: "USD")).font(.largeTitle.bold())
                        Text("Expenses").font(.caption)
                        let points = viewModel.accumulateTransactions()
                        if !points.isEmpty {
                            Chart(Array(points.enumerated()), id: \.offset) { point in
                                LineMark(x: .value("Day", point.offset), y: .value("Spending", point.element.1))
                            }.frame(height: 100)
                        }
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Expenses").font(.caption)
                                Text(viewModel.totalExpenses, format: .currency(code: "USD"))
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Net Balance").font(.caption)
                                Text(viewModel.balance, format: .currency(code: "USD"))
                            }
                        }
                    }
                    .padding().background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 20)).padding(.horizontal)
                    if let message = viewModel.storageError {
                        Text(message).foregroundStyle(.red).padding(.horizontal)
                    }
                    if viewModel.transactions.isEmpty {
                        ContentUnavailableView("Your ledger starts here", systemImage: "banknote", description: Text("Add an expense or income. Your entries stay on this device."))
                        Button("Add Transaction") { showingEntry = true }.buttonStyle(.borderedProminent).padding(.horizontal)
                        Button("Try Sample Data") {
                            do { try viewModel.loadSampleData() } catch { errorMessage = error.localizedDescription }
                        }.padding(.horizontal)
                        Text("Sample entries have fixed 2026 dates and are saved to your ledger. You can delete them from See All.").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                    }
                    RecentTransactionList().environmentObject(viewModel)
                }.padding(.vertical)
            }
            .navigationTitle("ExpenseTracker").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                NavigationLink { BudgetView(model: viewModel) } label: { Label("Budgets", systemImage: "chart.bar") }
                Button { showingEntry = true } label: { Label("Add Transaction", systemImage: "plus") }
            }
            .sheet(isPresented: $showingEntry) { TransactionEditor(model: viewModel) }
            .alert("Could Not Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}

struct TransactionEditor: View {
    @ObservedObject var model: TransactionListViewModel
    var existing: Transaction?
    @Environment(\.dismiss) private var dismiss
    @State private var merchant = ""
    @State private var amount = ""
    @State private var category = "Food & Dining"
    @State private var account = "Cash"
    @State private var date = Date()
    @State private var isExpense = true
    @State private var errorMessage: String?
    private let categories = ["Food & Dining", "Shopping", "Transport", "Housing", "Utilities", "Health", "Entertainment", "Income", "Other"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction") {
                    TextField("Merchant or description", text: $merchant)
                    TextField("Amount (USD)", text: $amount).keyboardType(.decimalPad)
                    Picker("Type", selection: $isExpense) { Text("Expense").tag(true); Text("Income").tag(false) }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Category", selection: $category) {
                        ForEach(Array(Set(categories + [category])).sorted(), id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Account", text: $account)
                }
                Section { Text("Amounts use USD and your region's decimal separator. Entries are saved locally; no bank connection or cloud sync.").font(.caption) }
                if let message = errorMessage { Section { Text(message).foregroundStyle(.red) } }
            }
            .navigationTitle(existing == nil ? "Add Transaction" : "Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear {
                guard let transaction = existing else { return }
                merchant = transaction.merchant
                amount = transaction.amount.formatted(.number.grouping(.never).precision(.fractionLength(2)))
                category = transaction.category; account = transaction.account
                date = transaction.parsedDate; isExpense = transaction.isExpense
            }
        }
    }

    private func save() {
        do {
            let value = try Transaction.parseAmount(amount)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = "MM/dd/yyyy"
            let transaction = Transaction(id: existing?.id ?? model.nextID, date: formatter.string(from: date), institution: existing?.institution ?? "Local", account: account.trimmingCharacters(in: .whitespacesAndNewlines), merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines), amount: value, type: isExpense ? "debit" : "credit", categoryId: ["Food & Dining": 5, "Shopping": 8, "Transport": 1, "Housing": 6, "Utilities": 2, "Health": 11, "Entertainment": 3, "Income": 7][category] ?? 0, category: category, isPending: existing?.isPending ?? false, isTransfer: existing?.isTransfer ?? false, isExpense: isExpense, isCashPurchase: account.lowercased() == "cash")
            try model.save(transaction)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

#Preview { ContentView() }

struct BudgetView: View {
    @ObservedObject var model: TransactionListViewModel
    @StateObject private var store = BudgetStore()
    @State private var month = BudgetStore.calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
    @FocusState private var amountFocused: Bool
    @State private var category = "Food & Dining"
    @State private var amount = ""
    @State private var feedback: String?
    @State private var errorMessage: String?

    private var monthKey: String { BudgetStore.monthKey(for: month) }
    private var insights: [CategorySpending] { store.insights(for: monthKey, transactions: model.transactions) }
    private var categories: [String] {
        Array(Set(BudgetStore.categories + model.transactions.filter(\.isExpense).map(\.category) + store.budgets.map(\.category))).sorted()
    }
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = BudgetStore.calendar
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month)
    }
    private func dollars(_ cents: Int64) -> String { (Double(cents) / 100).formatted(.currency(code: "USD")) }

    var body: some View {
        List {
            Section {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous Month")
                    Spacer()
                    Text(monthTitle).font(.headline).accessibilityIdentifier("budgetMonth")
                    Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next Month")
                }.buttonStyle(.borderless)
                Text("Category limits apply only to this Gregorian month. Unbudgeted categories still appear below. Income and transfers are excluded.").font(.caption).foregroundStyle(.secondary)
            }
            if let message = store.storageError { Section { Text(message).foregroundStyle(.red) } }
            if let message = model.storageError { Section { Text(message).foregroundStyle(.red) } }
            Section("Set a Category Limit") {
                Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }
                TextField("Monthly limit (USD)", text: $amount).keyboardType(.decimalPad).focused($amountFocused)
                if let feedback { Text(feedback).foregroundStyle(.secondary).accessibilityIdentifier("budgetFeedback") }
            }
            Section("Spending by Category") {
                if insights.isEmpty {
                    Text("No spending or limits this month. Set a limit above to get started.").foregroundStyle(.secondary)
                }
                ForEach(insights) { insight in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(insight.category).font(.headline)
                            Spacer()
                            Text(dollars(insight.spentCents) + " spent")
                        }
                        if let limit = insight.limitCents, let remaining = insight.remainingCents {
                            Text("Limit: " + dollars(limit))
                            ProgressView(value: insight.progress).tint(remaining < 0 ? .red : .blue)
                                .accessibilityLabel(insight.category + " budget used")
                            Text(remaining < 0 ? "Over by " + dollars(-remaining) : "Remaining: " + dollars(remaining))
                                .foregroundStyle(remaining < 0 ? Color.red : Color.secondary)
                            Button("Edit Limit") {
                                category = insight.category
                                amount = (Double(limit) / 100).formatted(.number.grouping(.never).precision(.fractionLength(2)))
                                feedback = "Editing \(category). Update the limit above and tap Save Limit."
                            }.buttonStyle(.borderless)
                        } else { Text("No budget set").foregroundStyle(.secondary) }
                    }
                    .padding(.vertical, 4)
                    .swipeActions {
                        if insight.limitCents != nil {
                            Button("Remove Limit", role: .destructive) {
                                do {
                                    try store.remove(month: monthKey, category: insight.category)
                                    loadSelectedLimit()
                                    feedback = "Limit removed. Transactions are unchanged."
                                } catch { errorMessage = error.localizedDescription }
                            }
                        }
                    }
                }
            }
            Section { Text("Budgets stay on this device. They do not repeat or roll over automatically; set each month's limits separately. Removing a limit never deletes spending.").font(.caption) }
        }
        .navigationTitle("Budgets")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save Limit") { saveLimit() }.disabled(store.storageError != nil)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { loadSelectedLimit() }
        .onChange(of: category) { _, _ in loadSelectedLimit() }
        .alert("Could Not Save Budget", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func loadSelectedLimit() {
        if let limit = store.budgets.first(where: { $0.month == monthKey && $0.category == category }) {
            amount = (Double(limit.limitCents) / 100).formatted(.number.grouping(.never).precision(.fractionLength(2)))
        } else { amount = "" }
        feedback = nil
    }

    private func moveMonth(_ offset: Int) {
        guard let next = BudgetStore.calendar.date(byAdding: .month, value: offset, to: month),
              (1...9999).contains(BudgetStore.calendar.component(.year, from: next)) else { return }
        month = next
        loadSelectedLimit()
    }

    private func saveLimit() {
        do {
            try store.setLimit(month: monthKey, category: category, amount: amount)
            amountFocused = false
            feedback = "Budget saved for \(monthTitle)."
        } catch { errorMessage = error.localizedDescription }
    }
}
