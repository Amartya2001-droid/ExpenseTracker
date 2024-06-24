//
//  MockData.swift
//  ExpenseTracker
//
//  Created by Amartya Karmakar on 2024-06-20.
//

import Foundation

extension Transaction {
    static let all: [Transaction] = [
        Transaction(id: 1, date: "04/12/2026", institution: "Chase", account: "Visa", merchant: "Apple", amount: 9.99, type: "debit", categoryId: 3, category: "Entertainment", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 2, date: "04/12/2026", institution: "Chase", account: "Visa", merchant: "Spotify", amount: 6.99, type: "debit", categoryId: 3, category: "Entertainment", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 3, date: "04/11/2026", institution: "Chase", account: "Visa", merchant: "Amazon", amount: 75.23, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 4, date: "04/10/2026", institution: "Chase", account: "Visa", merchant: "Whole Foods", amount: 62.50, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 5, date: "04/10/2026", institution: "Chase", account: "Visa", merchant: "Uber", amount: 12.75, type: "debit", categoryId: 1, category: "Auto & Transport", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 6, date: "04/09/2026", institution: "Chase", account: "Visa", merchant: "Netflix", amount: 15.49, type: "debit", categoryId: 3, category: "Entertainment", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 7, date: "04/08/2026", institution: "Chase", account: "Visa", merchant: "Starbucks", amount: 7.25, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: true),
        Transaction(id: 8, date: "04/07/2026", institution: "Chase", account: "Visa", merchant: "Chevron", amount: 48.30, type: "debit", categoryId: 1, category: "Auto & Transport", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 9, date: "04/06/2026", institution: "Chase", account: "Visa", merchant: "Target", amount: 89.17, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 10, date: "04/05/2026", institution: "Chase", account: "Checking", merchant: "Direct Deposit", amount: 2500.00, type: "credit", categoryId: 7, category: "Income", isPending: false, isTransfer: false, isExpense: false, isCashPurchase: false),
        Transaction(id: 11, date: "04/05/2026", institution: "Chase", account: "Visa", merchant: "Chipotle", amount: 13.45, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 12, date: "04/04/2026", institution: "Chase", account: "Visa", merchant: "AT&T", amount: 85.00, type: "debit", categoryId: 2, category: "Bills & Utilities", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 13, date: "04/03/2026", institution: "Chase", account: "Visa", merchant: "CVS Pharmacy", amount: 22.15, type: "debit", categoryId: 11, category: "Health", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 14, date: "04/02/2026", institution: "Chase", account: "Visa", merchant: "PG&E", amount: 134.75, type: "debit", categoryId: 2, category: "Bills & Utilities", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 15, date: "04/01/2026", institution: "Chase", account: "Visa", merchant: "Safeway", amount: 47.82, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 16, date: "03/31/2026", institution: "Chase", account: "Visa", merchant: "Nike", amount: 129.99, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 17, date: "03/29/2026", institution: "Chase", account: "Visa", merchant: "Lyft", amount: 18.30, type: "debit", categoryId: 1, category: "Auto & Transport", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 18, date: "03/27/2026", institution: "Chase", account: "Visa", merchant: "Trader Joe's", amount: 55.40, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 19, date: "03/25/2026", institution: "Chase", account: "Visa", merchant: "Hulu", amount: 13.99, type: "debit", categoryId: 3, category: "Entertainment", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 20, date: "03/22/2026", institution: "Chase", account: "Visa", merchant: "Gym Membership", amount: 40.00, type: "debit", categoryId: 11, category: "Health", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 21, date: "03/20/2026", institution: "Chase", account: "Visa", merchant: "Best Buy", amount: 249.99, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 22, date: "03/18/2026", institution: "Chase", account: "Visa", merchant: "Panera Bread", amount: 19.85, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 23, date: "03/15/2026", institution: "Chase", account: "Visa", merchant: "IKEA", amount: 312.40, type: "debit", categoryId: 6, category: "Home", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 24, date: "03/12/2026", institution: "Chase", account: "Visa", merchant: "Shell", amount: 52.10, type: "debit", categoryId: 1, category: "Auto & Transport", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 25, date: "03/10/2026", institution: "Chase", account: "Checking", merchant: "Freelance Payment", amount: 800.00, type: "credit", categoryId: 7, category: "Income", isPending: false, isTransfer: false, isExpense: false, isCashPurchase: false),
        Transaction(id: 26, date: "03/08/2026", institution: "Chase", account: "Visa", merchant: "Restaurant.com", amount: 88.50, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 27, date: "03/05/2026", institution: "Chase", account: "Visa", merchant: "Apple Store", amount: 199.00, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 28, date: "03/03/2026", institution: "Chase", account: "Visa", merchant: "Costco", amount: 187.65, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 29, date: "03/01/2026", institution: "Chase", account: "Checking", merchant: "Direct Deposit", amount: 2500.00, type: "credit", categoryId: 7, category: "Income", isPending: false, isTransfer: false, isExpense: false, isCashPurchase: false),
        Transaction(id: 30, date: "02/28/2026", institution: "Chase", account: "Visa", merchant: "Amazon", amount: 345.89, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 31, date: "02/25/2026", institution: "Chase", account: "Visa", merchant: "Delta Airlines", amount: 512.00, type: "debit", categoryId: 1, category: "Auto & Transport", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 32, date: "02/20/2026", institution: "Chase", account: "Visa", merchant: "Whole Foods", amount: 76.30, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
    ]
}
