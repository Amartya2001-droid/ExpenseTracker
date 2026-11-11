# ExpenseTracker

A native SwiftUI iOS expense tracker with an offline ledger, built with Swift, Foundation, Combine, and Apple Charts. No third-party packages or API keys are required.

## What works in source

- Add expenses and income with a merchant/description, category, account, date, and USD amount.
- Edit transactions by tapping a row in **See All**; swipe to edit or delete.
- Atomic JSON persistence in the app's Documents directory with iOS complete file protection. Save failures leave the in-memory ledger unchanged; unreadable saved files are preserved and block writes.
- Search merchant, category, or account; filter expenses; scroll through month groups sorted newest first.
- Current-month spending chart and total, all-time expenses, and net income minus expenses.
- Empty personal ledger on first launch. **Try Sample Data** explicitly imports bundled entries only into an empty ledger; sample dates are fixed in February–April 2026, so the current-month chart may be empty.
- Complete currency input validation (positive amounts, at most two fractional digits, local decimal separator, no grouping, maximum $999,999,999.99). Saved dates are strict Gregorian `MM/dd/yyyy`; malformed saved ledgers are not silently replaced with sample data.

The previous automatic remote sample fetch is removed: your personal ledger cannot be overwritten by an endpoint response. There is no bank connection, account authentication, cloud sync, multi-currency conversion, or receipt OCR. Money retains the original Double model for compatibility; input is parsed through Decimal and constrained to cents, but totals are not an accounting-grade decimal engine. Deleting the app can delete its local data; no in-app backup/export flow exists yet.

## Build and verification

Requires a Mac with compatible Xcode and an installed iOS simulator (deployment target iOS 17.5+, Swift 5 language mode). Open `ExpenseTracker.xcodeproj`, choose the shared `ExpenseTracker` scheme, then run:

```sh
xcodebuild test -project ExpenseTracker.xcodeproj -scheme ExpenseTracker \
  -destination 'platform=iOS Simulator,name=<installed iPhone simulator>' \
  CODE_SIGNING_ALLOWED=NO
```

The macOS GitHub Actions workflow builds and runs XCTest and UI tests, preserving the `.xcresult` artifact. Unit tests cover persistence/reload, editing/deletion, corrupt-file preservation, failed writes, amount/date validation, monthly totals, search, sample-data protection, and recent ordering. UI automation covers adding an expense and transaction navigation. `--uitesting` uses an in-memory ledger to isolate UI tests from personal data.

Linux cannot compile SwiftUI/UIKit/Combine or execute Xcode/XCTest. CI results establish only the tested simulator configuration. Manual layout, accessibility, physical-device behavior, signing, archives, and distribution remain unverified. Check the PR's CI result; source and a workflow file alone do not establish build success.

## Live status

**Not live yet — blocked by Apple signing/distribution setup, a verified release archive, and no supplied App Store or TestFlight URL.** There is no web demo; this is a native iOS app. No external API credentials are needed for the implemented offline features.

## Program history

- [Day 1 PR #2](https://github.com/Amartya2001-droid/ExpenseTracker/pull/2): CI/shared scheme, latest-five sorting, tests, and a colour type compile fix; macOS CI passed.
- [Day 2 PR #3](https://github.com/Amartya2001-droid/ExpenseTracker/pull/3): Gregorian/POSIX date parsing; branch macOS CI passed before opening.
- Core tracker work follows Amartya's expanded product scope after the original Day 2 report. It is stacked on those open PRs; merge dependencies first and retarget subsequent PRs to main.

Follow [AGENTS.md](AGENTS.md): branch and PR for changes, passing tests before a PR, no secrets, honest status, and reports in the [daily log](https://github.com/Amartya2001-droid/ExpenseTracker/issues/1). No licence is inferred; none is supplied.
