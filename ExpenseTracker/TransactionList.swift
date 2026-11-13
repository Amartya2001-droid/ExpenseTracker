import SwiftUI

struct TransactionList: View {
    @EnvironmentObject var viewModel: TransactionListViewModel
    @State private var search = ""
    @State private var expensesOnly = false
    @State private var editing: Transaction?
    @State private var errorMessage: String?

    private var filtered: [Transaction] { viewModel.filteredTransactions(search: search, expensesOnly: expensesOnly) }

    var body: some View {
        List {
            Toggle("Expenses only", isOn: $expensesOnly)
            if filtered.isEmpty {
                ContentUnavailableView("No transactions", systemImage: "magnifyingglass", description: Text("Try another search or add a transaction from Overview."))
            }
            ForEach(viewModel.groupTransactionsByMonth(), id: \.key) { month, transactions in
                let visible = transactions.filter { transaction in filtered.contains { $0.id == transaction.id } }
                if !visible.isEmpty {
                    Section(month) {
                        ForEach(visible) { transaction in
                            Button { editing = transaction } label: { TransactionRow(transaction: transaction) }.buttonStyle(.plain)
                                .swipeActions {
                                    Button("Delete", role: .destructive) {
                                        do { try viewModel.delete([transaction.id]) } catch { errorMessage = error.localizedDescription }
                                    }
                                    Button("Edit") { editing = transaction }.tint(.blue)
                                }
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Merchant, category, or account")
        .sheet(item: $editing) { TransactionEditor(model: viewModel, existing: $0) }
        .alert("Could Not Delete", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}
