//
//  Transaction.swift
//  ExpenseTracker
//
//  Created by Amartya Karmakar on 2024-06-20.
//

import Foundation
import SwiftUI

struct Transaction: Identifiable, Codable, Hashable {
    let id: Int
    let date: String
    let institution: String
    let account: String
    let merchant: String
    let amount: Double
    let type: String
    let categoryId: Int
    let category: String
    let isPending: Bool
    let isTransfer: Bool
    let isExpense: Bool
    let isCashPurchase: Bool
}

extension Transaction {
    var signedAmount: Double {
        isExpense ? -amount : amount
    }

    var parsedDate: Date {
        date.dateParsed()
    }

    var month: String {
        parsedDate.formatted(.dateTime.year().month(.wide))
    }

    var icon: String {
        switch categoryId {
        case 1: return "car.fill"
        case 2: return "bolt.fill"
        case 3: return "film.fill"
        case 4: return "banknote.fill"
        case 5: return "fork.knife"
        case 6: return "house.fill"
        case 7: return "arrow.down.circle.fill"
        case 8: return "bag.fill"
        case 9: return "arrow.left.arrow.right.circle.fill"
        case 10: return "face.smiling.fill"
        case 11: return "heart.fill"
        default: return "creditcard.fill"
        }
    }

    var accentColor: Color {
        switch categoryId {
        case 1: return .blue
        case 2: return .yellow
        case 3: return .purple
        case 4: return .red
        case 5: return .orange
        case 6: return .teal
        case 7: return .green
        case 8: return .pink
        case 9: return .indigo
        case 10: return .mint
        case 11: return Color(red: 0.9, green: 0.2, blue: 0.3)
        default: return .gray
        }
    }
}
