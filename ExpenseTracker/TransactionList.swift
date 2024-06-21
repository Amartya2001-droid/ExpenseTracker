//
//  TransactionList.swift
//  ExpenseTracker
//
//  Created by Amartya Karmakar on 2024-06-21.
//

import SwiftUI

struct TransactionList: View {
    @EnvironmentObject var viewModel: TransactionListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Transactions")
                .font(.title2)
                .fontWeight(.bold)
                .padding([.top, .horizontal])

            ForEach(viewModel.groupTransactionsByMonth(), id: \.key) { month, transactions in
                Section {
                    ForEach(transactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .padding(.horizontal)
                    }
                } header: {
                    Text(month)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding([.horizontal, .top])
                        .padding(.bottom, 4)
                }
            }
        }
    }
}

#Preview {
    let vm = TransactionListViewModel()
    vm.transactions = Transaction.all
    return ScrollView {
        TransactionList()
    }
    .environmentObject(vm)
}
