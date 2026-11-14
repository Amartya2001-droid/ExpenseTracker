import Foundation

/// Gregorian local-day schedules anchored to the original start date (no month-end drift).
struct RecurringExpense: Identifiable, Codable, Equatable {
    enum Frequency: String, Codable, CaseIterable { case weekly, monthly }
    var id = UUID().uuidString
    var merchant: String
    var category: String
    var account: String
    var amountCents: Int64
    var startDate: String
    var frequency: Frequency
    var nextIndex = 0

    static var calendar: Calendar { Calendar(identifier: .gregorian) }
    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }

    func occurrence(at index: Int) -> Date? {
        guard index >= 0, index <= 1_000_000, let start = startDate.validTransactionDate else { return nil }
        let calendar = Self.calendar
        let result: Date?
        switch frequency {
        case .weekly:
            result = calendar.date(byAdding: .day, value: index * 7, to: start)
        case .monthly:
            guard let monthStart = calendar.dateInterval(of: .month, for: start)?.start,
                  let target = calendar.date(byAdding: .month, value: index, to: monthStart),
                  let days = calendar.range(of: .day, in: .month, for: target) else { return nil }
            let day = min(calendar.component(.day, from: start), days.count)
            result = calendar.date(byAdding: .day, value: day - 1, to: target)
        }
        guard let date = result, (1...9999).contains(calendar.component(.year, from: date)) else { return nil }
        return date
    }

    enum ScheduleError: LocalizedError {
        case invalid, editInPast, exhaustedIDs
        var errorDescription: String? {
            switch self {
            case .invalid: return "Enter a description, category, valid date and positive USD amount for this schedule."
            case .editInPast: return "Choose today or a future date for the edited schedule. Posted entries will stay unchanged."
            case .exhaustedIDs: return "No transaction IDs are available; no occurrences were posted."
            }
        }
    }
}

/// Schedules, posting checkpoints, deletion tombstones and entries commit in one atomic file.
struct LedgerSnapshot: Codable {
    var version = 1
    var transactions: [Transaction]
    var recurringExpenses: [RecurringExpense]
    var postedOccurrences: Set<String>
}
