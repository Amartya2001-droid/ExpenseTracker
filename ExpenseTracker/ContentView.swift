//
//  ContentView.swift
//  ExpenseTracker
//
//  Created by Amartya Karmakar on 2024-06-19.
//

import SwiftUI
import Charts

struct ContentView: View {
    @StateObject var viewModel = TransactionListViewModel()
    @State private var showAllTransactions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Overview")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(Date(), style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // MARK: - Total Balance Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.33, green: 0.45, blue: 0.95),
                                         Color(red: 0.55, green: 0.35, blue: 0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Expenses")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Text(viewModel.totalExpenses, format: .currency(code: "USD"))
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.title)
                                    .foregroundStyle(.white.opacity(0.8))
                            }

                            // MARK: - Spending Chart
                            let prefixSum = viewModel.accumulateTransactions()
                            if !prefixSum.isEmpty {
                                Chart {
                                    ForEach(Array(prefixSum.enumerated()), id: \.offset) { index, entry in
                                        LineMark(
                                            x: .value("Day", index),
                                            y: .value("Expenses", entry.1)
                                        )
                                        .foregroundStyle(.white)
                                        .interpolationMethod(.catmullRom)

                                        AreaMark(
                                            x: .value("Day", index),
                                            y: .value("Expenses", entry.1)
                                        )
                                        .foregroundStyle(
                                            .linearGradient(
                                                colors: [.white.opacity(0.4), .clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .interpolationMethod(.catmullRom)
                                    }
                                }
                                .chartXAxis(.hidden)
                                .chartYAxis(.hidden)
                                .frame(height: 80)
                            }
                        }
                        .padding(20)
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity)

                    // MARK: - Recent Transactions
                    RecentTransactionList()
                        .environmentObject(viewModel)
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("ExpenseTracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "bell.badge")
                        .symbolRenderingMode(.multicolor)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
