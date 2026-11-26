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

The previous automatic remote sample fetch is removed: your personal ledger cannot be overwritten by an endpoint response. There is no bank connection, account authentication, cloud sync, multi-currency conversion, or receipt OCR. Money retains the original Double model for compatibility; input is parsed through Decimal and constrained to cents, but totals are not an accounting-grade decimal engine. Deleting the app can delete its local data; manual JSON backup and CSV export are available; automatic backups are not implemented. JSON restore requires validation, review and explicit replacement confirmation.

## Monthly budgets and insights

Open **Budgets** from Overview. Choose a month with the previous/next buttons, choose a category, enter a positive USD limit and tap **Save Limit**. Saving again updates that category in that month. Tap **Edit Limit** to fill the form with an existing limit, or swipe a budget row to **Remove Limit**. Removing a limit never removes transactions.

- Limits apply to one Gregorian calendar month in the device's local time zone; they do not automatically repeat, roll over, or notify you. Recurring schedules can post ledger expenses, but budget limits remain month-specific.
- Category rows show spending, a capped progress bar, and the amount remaining or over the limit. Categories without a budget still show spending; budgets without spending show the full amount remaining. Income and transfers are excluded from these insights.
- Limits and category spending comparisons use integer USD cents, converting each validated ledger entry separately. The underlying ledger and its original Overview totals still use Double.
- Before the first confirmed restore, budgets use file-protected `budgets.json`. After restore, ledger and budgets share one atomic app snapshot; each normal save preserves the other data set. Unreadable/invalid/duplicate budgets preserve the original file and block budget changes. Failed writes leave in-memory limits unchanged. Full JSON backups include budgets and can be reviewed for explicit full replacement.
- Categories match the ledger's exact category names. Limits are not one combined monthly allowance; unbudgeted spending remains visible, and no automatic categorization or predictions are claimed.

## Recurring expenses

Open **Recurring** from Overview, then **Add Schedule**. Enter a description, positive USD amount, category/account, first date, and weekly or monthly cadence. Save to create the schedule; due entries are then added to the ledger. They are marked **Recurring** and participate in ordinary totals and budget insights. Future scheduled entries are not counted as spending before they are posted.

- Posting runs when Overview appears, when the app returns to the foreground, after dismissing a schedule editor, or via **Post Due**. There is no background execution guarantee, notification service, bank connection or actual payment action. If you do not open the app, missed dates wait for the next posting pass.
- Weekly schedules use seven Gregorian local-calendar days. Monthly schedules retain the anchor day: January 31 → February 28/29 → March 31. Dates use the device's local time zone, not elapsed UTC hours.
- Tap a schedule to edit future postings. Its **Next date** must be today or later. Changing amount/details while keeping the same next date/cadence retains the original monthly anchor; choosing a different next date/cadence starts a new future schedule. Existing ledger entries stay unchanged.
- Swipe a schedule to **Delete Schedule**; posted history remains. Edit/delete individual occurrences in **See All** like ordinary entries. A deleted occurrence is not recreated; persistent occurrence keys and checkpoints prevent duplicates, including after restart or schedule edits. Creating an entirely new schedule creates a new identity and can intentionally post new entries on the same date.
- A posting pass handles at most 500 schedule steps across all schedules. For a large backlog, tap **Post Due** again. Posting errors are shown and leave the previous ledger/checkpoints unchanged.
- `transactions.json` now stores a versioned snapshot containing entries, schedules and posting history, written atomically with iOS file protection. Existing array-only ledgers still load and migrate on the next successful mutation; unreadable/unknown-version snapshots are preserved and block changes. Legacy budget storage remains separate until the first confirmed restore. Posting history is retained after deletion, so storage grows with usage. Use a full JSON backup to preserve this state; restoring it requires explicit confirmation; older app versions cannot read the new snapshot formats.

## Ledger backup and export

Open **Backup & Export** near the top of Overview. The screen shows transaction, schedule and budget counts. Choose **Export JSON Backup** or **Export CSV** to review the generated contents. **Cancel Preview** returns to the export screen; **Save to Files** opens the real iOS destination picker. Filenames include a UTC timestamp. Preparing or cancelling the app-owned preview does not rewrite source files or advance recurring checkpoints; ordinary app-foreground recurring posting still runs independently. Exports capture a snapshot when you tap the export button.

- **JSON backup**: UTF-8, versioned `ExpenseTracker` format with USD currency, an ISO-8601 UTC export timestamp, the complete ledger snapshot (transactions, schedules, posting checkpoints and deleted-occurrence history) and all category budgets. Original text and recurring identity are retained. This is the supported full-fidelity restore format.
- **CSV export**: transaction rows only, sorted by Gregorian date then ID. Dates use `yyyy-MM-dd`; amounts use two decimal places with a period and no grouping. Both original positive amount and signed amount (negative expense, positive income) are included, alongside transaction flags and recurring ID. Text is quoted, embedded quotes doubled, and records separated by CRLF; Unicode and embedded newlines are retained. Formula-like user text, including whitespace-prefixed `=`, `+`, `-`, `@`, is prefixed with an apostrophe for spreadsheet handling; trusted numeric amounts retain their sign. CSV is for analysis, not a replacement for the full JSON backup.
- Full backup fails if the ledger or budgets cannot be read; it never silently exports an empty substitute for corrupt data. A healthy ledger can still export CSV if only budget storage is unreadable. Invalid in-memory transactions are rejected before export.
- Files are **unencrypted** and contain financial details/account labels. Choose a trusted destination. The app does not automatically upload them; choosing a cloud Files provider is your own save action. No API key or cloud account is required by the app.
- **No automatic restore, automatic backup schedule, encrypted archive or CSV import is implemented.** Always retain a separate current backup before destructive replacement. Actual physical-device/provider import, save, cancellation and retrieval remain unverified.

Automated UI verification now exercises the **production preview**, checks actual CSV/JSON contents and app-owned cancellation, and requires an interactive export screen afterward. A separate smoke test verifies real Files-picker presentation only; terminating the app is cleanup, not a successful save/cancel assertion. No test-only exporter is substituted.

**System Files-picker cancellation/save/retrieval remain unverified manually.** Run 43974590546 showed the old coordinate tap opening the system **More** menu, despite an AX element labelled Cancel. The corrected checks stop automating that misleading control rather than claiming the modal was dismissed. See [export verification evidence and the manual Apple-host procedure](docs/EXPORT-VERIFICATION.md). Manual provider, physical-device, spreadsheet compatibility, accessibility/layout and release verification are still outstanding.

## Restore from a JSON backup

Open **Backup & Export → Import JSON Backup** to select a JSON file. **Paste Backup JSON** is an app-owned raw JSON entry alternative using the identical production validator and preview path; it is not a test-only importer.

1. Selecting/reading a file or tapping **Validate Backup** performs validation only. Nothing is restored automatically.
2. **Restore Preview** shows current→backup counts and every added, removed or changed transaction, schedule, budget and posting-history key. Expand a record to inspect its complete before/after fields; unchanged records are not listed. No change-list truncation is used.
3. **Cancel Restore**, cancelling the input, or cancelling the confirmation dialog makes no replacement. **Replace…** opens a separate destructive confirmation. Only **Replace Ledger and Budgets** commits the reviewed replacement. There is no merge or in-app undo.
4. A preview becomes invalid if current memory or source files change while reviewing. Cancel and validate again. Future schedules keep their saved checkpoints; normal foreground posting resumes independently after restore.

The reader bounds input at **5 MiB** and **20,000 total records/history keys**. It checks the current ExpenseTracker/version-1/USD envelope and ledger schema, required and unknown record fields, typed values, IDs, dates, cent amounts, schedules, unique budgets/history and schedule-checkpoint consistency. CSV, malformed data, unsupported versions/currencies and inconsistent recurring history are rejected before a preview or any write. Security-scoped Files access is released after reading.

A confirmed restore writes ledger, schedules, posting history and budgets together to **`restored-app-state.json`**, with atomic replacement and complete file protection. Memory changes only after the write succeeds. Existing `transactions.json` and `budgets.json` are retained untouched; subsequent normal ledger/budget saves update the canonical snapshot while preserving the other data set. Stale writers are rejected. A corrupt canonical snapshot blocks both stores instead of silently falling back to obsolete legacy files. Older app versions do not understand this canonical snapshot; do not downgrade expecting the restored state to appear.

Restore currently fails closed when existing app data is unreadable, because an exact change preview cannot be computed; there is no force-recovery/quarantine UI. Export a current backup before replacement. Manual Apple-device import/provider behavior, lock/unlock and crash/power-loss testing remain unverified. Unit tests verify file reads, validation, no writes before confirmation, exact change details, stale previews, write failures, successful reload, preserved legacy files, subsequent writes and recurring deletion history. UI tests enter actual backup JSON through the production input, inspect real preview content, cancel without count changes, and require a separate confirmation before replacement. They do not pretend to operate the system Files picker.

## Build and verification

Requires a Mac with compatible Xcode and an installed iOS simulator (deployment target iOS 17.5+, Swift 5 language mode). Open `ExpenseTracker.xcodeproj`, choose the shared `ExpenseTracker` scheme, then run:

```sh
xcodebuild test -project ExpenseTracker.xcodeproj -scheme ExpenseTracker \
  -destination 'platform=iOS Simulator,name=<installed iPhone simulator>' \
  CODE_SIGNING_ALLOWED=NO
```

The macOS GitHub Actions workflow builds and runs XCTest and UI tests, preserving the `.xcresult` artifact. Unit tests cover persistence/reload, editing/deletion, corrupt-file preservation, failed writes, amount/date validation, monthly totals, search, sample-data protection, recent ordering, budget CRUD/reload, month/category isolation, cents arithmetic, unbudgeted spending, transfer/income exclusions and budget storage failures. Recurring tests cover anchored month ends/leap years, weekly dates, due-only/idempotent posting, deleted occurrence protection, future edits/removal, legacy migration/reload, bounded catch-up and atomic failure/corrupt snapshot handling. UI automation covers adding an expense, transaction navigation, saving a budget/switching months, and creating a recurring schedule that posts into the ledger. Export tests cover JSON round trips (including recurring deletion protection), source-file non-mutation, CSV quoting/Unicode/newlines/formula-like text, date/ID ordering, money precision, empty ledgers and unreadable sources. UI automation checks source counts, CSV/JSON preview contents and app-owned cancellation; a separate real Files-picker presentation smoke test does not claim system cancellation or saving. `--uitesting` uses an in-memory ledger and budget store to isolate UI tests from personal data.

Linux cannot compile SwiftUI/UIKit/Combine or execute Xcode/XCTest. CI results establish only the tested simulator configuration. Manual layout, accessibility, physical-device behavior, signing, archives, and distribution remain unverified. Check the PR's CI result; source and a workflow file alone do not establish build success.

## Live status

**Not live yet — blocked by Apple signing/distribution setup, a verified release archive, and no supplied App Store or TestFlight URL.** There is no web demo; this is a native iOS app. No external API credentials are needed for the implemented offline features.

## Program history

- [Day 1 PR #2](https://github.com/Amartya2001-droid/ExpenseTracker/pull/2): CI/shared scheme, latest-five sorting, tests, and a colour type compile fix; macOS CI passed.
- [Day 2 PR #3](https://github.com/Amartya2001-droid/ExpenseTracker/pull/3): Gregorian/POSIX date parsing; branch macOS CI passed before opening.
- [Day 3 PR #6](https://github.com/Amartya2001-droid/ExpenseTracker/pull/6) is merged: persistent offline ledger, with passing branch and PR macOS CI.
- [Day 4 PR #8](https://github.com/Amartya2001-droid/ExpenseTracker/pull/8) is merged: monthly category budgets and spending insights.
- [Day 5 PR #10](https://github.com/Amartya2001-droid/ExpenseTracker/pull/10) is merged: weekly/monthly recurring expenses. Merged-main CI is green at 195a33c.
- Day 6 backup/export implements [issue #11](https://github.com/Amartya2001-droid/ExpenseTracker/issues/11) from that main baseline. Ship-week restore is tracked in issue #13; it is a separate PR after the failing regression, not self-merged.
- Core tracker work follows Amartya's expanded product scope. The Day 3 branch starts from main after merged PR #4 and targets main directly; it is not stacked on an unmerged branch.

Follow [AGENTS.md](AGENTS.md): branch and PR for changes, passing tests before a PR, no secrets, honest status, and reports in the [daily log](https://github.com/Amartya2001-droid/ExpenseTracker/issues/1). No licence is inferred; none is supplied.
