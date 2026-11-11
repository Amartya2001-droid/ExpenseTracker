//
//  TransactionListViewModel.swift
//  ExpenseTracker
//
//  Created by Amartya Karmakar on 2024-06-20.
//

import Foundation
import Combine

final class TransactionListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []

    private var cancellables = Set<AnyCancellable>()

    init(fetchOnInit: Bool = true) {
        if fetchOnInit { fetchTransactions() }
    }

    func fetchTransactions() {
        guard let url = URL(string: "https://designcode.io/data/transactions.json") else {
            self.transactions = Transaction.all
            return
        }

        URLSession.shared.dataTaskPublisher(for: url)
            .tryMap { (data, response) -> Data in
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: [Transaction].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure = completion {
                    self?.transactions = Transaction.all
                }
            } receiveValue: { [weak self] transactions in
                self?.transactions = transactions
            }
            .store(in: &cancellables)
    }

    func groupTransactionsByMonth() -> [(key: String, value: [Transaction])] {
        guard !transactions.isEmpty else { return [] }
        let grouped = Dictionary(grouping: transactions) { $0.month }
        return grouped.sorted { a, b in
            guard let dateA = a.value.first?.parsedDate,
                  let dateB = b.value.first?.parsedDate else { return false }
            return dateA > dateB
        }
    }

    func accumulateTransactions() -> [(String, Double)] {
        guard !transactions.isEmpty else { return [] }
        let today = Date()
        guard let interval = Calendar.current.dateInterval(of: .month, for: today) else { return [] }

        let calendar = Calendar.current
        var sum = 0.0
        var result: [(String, Double)] = []
        var current = interval.start

        while current <= today {
            let dayTotal = transactions
                .filter { $0.isExpense && calendar.isDate($0.parsedDate, inSameDayAs: current) }
                .reduce(0) { $0 + $1.amount }
            sum += dayTotal
            if sum > 0 {
                let label = current.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
                result.append((label, sum))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    var totalExpenses: Double {
        transactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
    }

    var recentTransactions: [Transaction] {
        Array(transactions.sorted { $0.parsedDate > $1.parsedDate }.prefix(5))
    }
}
