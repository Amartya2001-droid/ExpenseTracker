//
//  MockData.swift
//  ExpenseTracker
//
//  Created by Amartya Karmakar on 2024-06-20.
//

import Foundation

extension Transaction {
    static let all: [Transaction] = [
        Transaction(id: 1, date: "01/24/2024", institution: "Chase", account: "Visa", merchant: "Apple", amount: 9.99, type: "debit", categoryId: 3, category: "Entertainment", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 2, date: "01/24/2024", institution: "Chase", account: "Visa", merchant: "Spotify", amount: 6.99, type: "debit", categoryId: 3, category: "Entertainment", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 3, date: "01/23/2024", institution: "Chase", account: "Visa", merchant: "Amazon", amount: 75.23, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 4, date: "01/22/2024", institution: "Chase", account: "Visa", merchant: "Whole Foods", amount: 62.50, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 5, date: "01/22/2024", institution: "Chase", account: "Visa", merchant: "Uber", amount: 12.75, type: "debit", categoryId: 1, category: "Auto & Transport", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 6, date: "01/21/2024", institution: "Chase", account: "Visa", merchant: "Netflix", amount: 15.49, type: "debit", categoryId: 3, category: "Entertainment", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 7, date: "01/20/2024", institution: "Chase", account: "Visa", merchant: "Starbucks", amount: 7.25, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: true),
        Transaction(id: 8, date: "01/19/2024", institution: "Chase", account: "Visa", merchant: "Chevron", amount: 48.30, type: "debit", categoryId: 1, category: "Auto & Transport", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 9, date: "01/18/2024", institution: "Chase", account: "Visa", merchant: "Target", amount: 89.17, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 10, date: "01/17/2024", institution: "Chase", account: "Checking", merchant: "Direct Deposit", amount: 2500.00, type: "credit", categoryId: 7, category: "Income", isPending: false, isTransfer: false, isExpense: false, isCashPurchase: false),
        Transaction(id: 11, date: "01/17/2024", institution: "Chase", account: "Visa", merchant: "Chipotle", amount: 13.45, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 12, date: "01/16/2024", institution: "Chase", account: "Visa", merchant: "AT&T", amount: 85.00, type: "debit", categoryId: 2, category: "Bills & Utilities", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 13, date: "01/15/2024", institution: "Chase", account: "Visa", merchant: "CVS Pharmacy", amount: 22.15, type: "debit", categoryId: 11, category: "Health", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 14, date: "01/14/2024", institution: "Chase", account: "Visa", merchant: "PG&E", amount: 134.75, type: "debit", categoryId: 2, category: "Bills & Utilities", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 15, date: "01/13/2024", institution: "Chase", account: "Visa", merchant: "Safeway", amount: 47.82, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 16, date: "01/12/2024", institution: "Chase", account: "Visa", merchant: "Nike", amount: 129.99, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 17, date: "01/11/2024", institution: "Chase", account: "Visa", merchant: "Lyft", amount: 18.30, type: "debit", categoryId: 1, category: "Auto & Transport", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 18, date: "01/10/2024", institution: "Chase", account: "Visa", merchant: "Trader Joe's", amount: 55.40, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 19, date: "01/09/2024", institution: "Chase", account: "Visa", merchant: "Hulu", amount: 13.99, type: "debit", categoryId: 3, category: "Entertainment", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 20, date: "01/08/2024", institution: "Chase", account: "Visa", merchant: "Gym Membership", amount: 40.00, type: "debit", categoryId: 11, category: "Health", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 21, date: "01/07/2024", institution: "Chase", account: "Visa", merchant: "Best Buy", amount: 249.99, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 22, date: "01/06/2024", institution: "Chase", account: "Visa", merchant: "Panera Bread", amount: 19.85, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 23, date: "01/05/2024", institution: "Chase", account: "Visa", merchant: "IKEA", amount: 312.40, type: "debit", categoryId: 6, category: "Home", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 24, date: "01/04/2024", institution: "Chase", account: "Visa", merchant: "Shell", amount: 52.10, type: "debit", categoryId: 1, category: "Auto & Transport", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 25, date: "01/03/2024", institution: "Chase", account: "Checking", merchant: "Freelance Payment", amount: 800.00, type: "credit", categoryId: 7, category: "Income", isPending: false, isTransfer: false, isExpense: false, isCashPurchase: false),
        Transaction(id: 26, date: "12/31/2023", institution: "Chase", account: "Visa", merchant: "Restaurant.com", amount: 88.50, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 27, date: "12/29/2023", institution: "Chase", account: "Visa", merchant: "Apple Store", amount: 199.00, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 28, date: "12/27/2023", institution: "Chase", account: "Visa", merchant: "Costco", amount: 187.65, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 29, date: "12/24/2023", institution: "Chase", account: "Checking", merchant: "Direct Deposit", amount: 2500.00, type: "credit", categoryId: 7, category: "Income", isPending: false, isTransfer: false, isExpense: false, isCashPurchase: false),
        Transaction(id: 30, date: "12/23/2023", institution: "Chase", account: "Visa", merchant: "Amazon", amount: 345.89, type: "debit", categoryId: 8, category: "Shopping", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 31, date: "12/20/2023", institution: "Chase", account: "Visa", merchant: "Delta Airlines", amount: 512.00, type: "debit", categoryId: 1, category: "Auto & Transport", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
        Transaction(id: 32, date: "12/18/2023", institution: "Chase", account: "Visa", merchant: "Whole Foods", amount: 76.30, type: "debit", categoryId: 5, category: "Food & Dining", isPending: false, isTransfer: false, isExpense: true, isCashPurchase: false),
    ]
}
