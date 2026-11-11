# ExpenseTracker

SwiftUI iOS demo for viewing sample expenses, a spending chart, and transaction lists.

## Current status

- Source implements an overview, total expenses, five recent transactions, and a list grouped by month.
- It requests sample JSON from `https://designcode.io/data/transactions.json` and silently falls back to bundled mock data on request or decoding failure. This is not a personal finance backend or bank connection.
- Bundled transactions have fixed February–April 2026 dates. The chart shows only the current month, so fallback data can leave it empty. The total includes expenses across all months.
- Live status: **not live yet — blocked by an unverified release build, Apple signing/distribution setup, and no supplied App Store or TestFlight URL.** No live release was verified during the audit.
- Linux cannot build SwiftUI, Combine, UIKit, or iOS simulator tests. Build and test verification must come from the macOS GitHub Actions workflow or Xcode on a Mac. A workflow file alone is not evidence of a successful build.

## Build and test

The project was created with Xcode 15.4, uses Swift 5 language mode, and targets iOS 17.5 or later. Open `ExpenseTracker.xcodeproj` on a Mac and select the shared `ExpenseTracker` scheme and an installed iPhone simulator.

```sh
xcodebuild test -project ExpenseTracker.xcodeproj -scheme ExpenseTracker \
  -destination 'platform=iOS Simulator,name=<installed iPhone simulator>' \
  CODE_SIGNING_ALLOWED=NO
```

GitHub Actions runs simulator build, unit tests, and UI smoke tests on `macos-15` for branch pushes and pull requests, and retains the `.xcresult` bundle. Branch push validation allows tests to pass before opening a PR. CI uses the runner's default Xcode and prints its version; it does not verify device signing or an App Store archive.

## Day 1 audit

Baseline: `93288ff` (June 24, 2024). No existing issues or open PRs were found at triage; no CI or shared scheme existed. Original unit tests were empty templates and UI tests only launched the app.

- No external package dependencies are configured. Charts use Apple's `Charts` framework; the previous README's SwiftUICharts dependency claim was incorrect.
- The existing iOS 17.5 target supports the visible NavigationStack, Charts, previews, and toolbar APIs. Current SDK compilation and deprecation warnings require macOS CI; Linux source inspection cannot establish build success.
- Initial CI on Xcode 16.4 / iOS 18.5 SDK exposed a compile error in the amount color ternary (`HierarchicalShapeStyle` versus `Color`); both branches now explicitly use `Color`.
- Recent transactions previously depended on endpoint ordering. They now sort by date before taking five; regression tests use bundled data without a network request.
- Remaining risks: date parsing still substitutes today's date on invalid input; monthly grouping uses formatted strings; the remote sample endpoint's availability was not verified; network fallback has no visible error/sample-data indication; the full transaction view has no scroll container. These require follow-up validation and small fixes, not new features.
- The checked-in development team and bundle identifiers are historical project configuration. Distribution ownership, signing, and release status need Amartya's confirmation. No licence file is present; no licence is inferred.

## Day 2 audit

- Fixed-format endpoint dates now use `en_US_POSIX` and the Gregorian calendar, so a device's selected calendar cannot reinterpret the year. Regression tests cover month/day order, leap day, and year boundaries.
- Invalid-date handling remains unresolved: the existing parser substitutes today's date. Changing this safely needs a separate data-validation policy; no synthetic replacement date is introduced here.
- No third-party packages are configured to update. Layout/scrolling and device-specific behavior remain unverified and unchanged. Linux cannot execute XCTest or Xcode; consult the branch/PR macOS CI result for build and test evidence.

## Contributing

Follow [AGENTS.md](AGENTS.md): work on a branch, pass tests before opening a PR, and report in the [daily log](https://github.com/Amartya2001-droid/ExpenseTracker/issues/1). Day 1 adds no product features.
