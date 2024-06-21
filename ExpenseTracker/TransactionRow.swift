//
//  TransactionRow.swift
//  ExpenseTracker
//
//  Created by Amartya Karmakar on 2024-06-21.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 20) {
            // Category icon
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(transaction.accentColor.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: transaction.icon)
                        .font(.title2)
                        .foregroundStyle(transaction.accentColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(transaction.category)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(transaction.parsedDate, style: .date)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.signedAmount, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(transaction.isExpense ? .primary : .green)

                if transaction.isPending {
                    Text("Pending")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    TransactionRow(transaction: Transaction.all[0])
        .padding()
}
