//
//  RecentTransactionList.swift
//  ExpenseTracker
//
//  Created by Amartya Karmakar on 2024-06-22.
//

import SwiftUI

struct RecentTransactionList: View {
    @EnvironmentObject var viewModel: TransactionListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Transactions")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                NavigationLink {
                    TransactionList()
                        .navigationTitle("Transactions")
                        .navigationBarTitleDisplayMode(.inline)
                        .environmentObject(viewModel)
                } label: {
                    HStack(spacing: 4) {
                        Text("See All")
                        Image(systemName: "chevron.right")
                            .imageScale(.small)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)

            ForEach(viewModel.recentTransactions) { transaction in
                TransactionRow(transaction: transaction)
                    .padding(.horizontal)

                if transaction.id != viewModel.recentTransactions.last?.id {
                    Divider()
                        .padding(.leading, 80)
                }
            }
        }
    }
}

#Preview {
    let vm = TransactionListViewModel()
    vm.transactions = Transaction.all
    return NavigationStack {
        RecentTransactionList()
    }
    .environmentObject(vm)
}
