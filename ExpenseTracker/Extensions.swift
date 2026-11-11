//
//  Extensions.swift
//  ExpenseTracker
//
//  Created by Amartya Karmakar on 2024-06-20.
//

import Foundation
import SwiftUI

// MARK: - String
extension String {
    func dateParsed() -> Date {
        let formatter = DateFormatter()
        // The endpoint uses Gregorian US-format dates, independent of device settings.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.date(from: self) ?? Date()
    }
}

// MARK: - Date
extension Date {
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

// MARK: - Double
extension Double {
    func currencyFormatted() -> String {
        self.formatted(.currency(code: "USD"))
    }

    func currencyFormattedAbs() -> String {
        abs(self).formatted(.currency(code: "USD"))
    }
}

// MARK: - Color
extension Color {
    static let systemBackground = Color(UIColor.systemBackground)
    static let listRowBackground = Color(UIColor.secondarySystemBackground)
    static let customGray = Color(UIColor.systemGray5)
}
