# ExpenseTracker

ExpenseTracker is a SwiftUI application designed to help users track their expenses efficiently. This app provides a user-friendly interface to view an overview of their expenses, recent transactions, and a detailed list of all transactions.

## Features

- **Overview Screen:** Provides a summary of the user's total expenses with a line chart visualization.
- **Recent Transactions:** Displays the five most recent transactions for quick access.
- **Detailed Transaction List:** Groups and lists transactions by month.
- **Data Fetching:** Fetches transaction data from a remote JSON endpoint.

## Installation

To run this project, you need to have Xcode installed on your Mac. Follow the steps below to set up and run the app:

1. **Clone the Repository:**
    ```bash
    git clone https://github.com/Amartya2001-droid/ExpenseTracker
    cd ExpenseTracker
    ```

2. **Open the Project:**
    Open `ExpenseTracker.xcodeproj` in Xcode.

3. **Build and Run:**
    Select the appropriate simulator or your device and click the "Run" button.

## Usage

- **Overview Screen:**
  - Displays a line chart of the user's accumulated expenses over time.
  - Shows the total expenses in the specified currency.

- **Recent Transactions:**
  - Lists the five most recent transactions.
  - Provides a link to view all transactions.

- **Transaction List:**
  - Groups transactions by month.
  - Displays each transaction's details, including merchant, category, date, and amount.

## Code Structure

- **ContentView.swift:** The main view of the app, displaying the overview and recent transactions.
- **RecentTransactionList.swift:** A view displaying the recent transactions.
- **TransactionList.swift:** A view displaying the detailed list of all transactions grouped by month.
- **TransactionRow.swift:** A view representing a single transaction row.
- **TransactionListViewModel.swift:** A view model handling the fetching and processing of transaction data.
- **Extensions.swift:** Contains utility extensions for colors, date formatting, and other helper functions.
- **ExpenseTrackerApp.swift:** The entry point of the SwiftUI app.

## Dependencies

- [SwiftUICharts](https://github.com/willdale/SwiftUICharts): Used for rendering charts in the app.

## Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue. If you'd like to contribute code, please fork the repository and submit a pull request.


## Author

Created by Amartya Karmakar.

---
