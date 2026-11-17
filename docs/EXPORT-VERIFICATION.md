# Export verification boundaries

## Evidence behind the corrected tests

Run [43974590546](https://github.com/Amartya2001-droid/ExpenseTracker/actions/runs/43974590546) passed 34 unit tests but failed the Files cancellation UI test. Its `EXPORT RETURN HIERARCHY` shows the app behind a system menu containing **New Folder**, **Icons**, **List**, and sort options. The coordinate tap on an AX `Other` labelled **Cancel** actually opened **More**. The earlier `Browse View (Picker)` disappearance was not proof that the system modal had dismissed. Keeping the source-screen interactivity assertion exposed that false positive.

This demonstrates an invalid system-control automation assumption, not a JSON/CSV data-generation failure. It does **not** prove that Files save/cancel works on devices or every provider.

## Automated contract

The production app now prepares an immutable export, shows its contents in an app-owned preview, and offers **Cancel Preview** or **Save to Files**. The preview and file document use the same full data; only displayed preview text is shortened for large exports.

CI verifies:

- JSON backup completeness, CSV encoding/formula-like text handling, corrupt-source rejection and byte-for-byte preservation of source files through unit tests.
- Actual CSV preview content and parsed JSON preview contents from a user-created expense, app-owned cancellation, unchanged source counts, no error, and an interactive export screen afterward.
- A separate smoke test invokes the real **Save to Files** action and verifies the system picker appears. App termination is test cleanup, **not** an assertion of successful system cancellation or saving.

There are no test-only replacement exporters, disabled tests, or coordinate taps on system controls. System Files cancellation, saving and provider retrieval are deliberately outside the automated guarantee. CI green must not be described as those manual checks passing.

## Manual Apple-host verification — not performed in Linux

On a compatible simulator and a physical device, record the tested commit, device/OS and Files provider, then:

1. Create known expenses/income, a due recurring schedule and a category budget. Use future dates for any additional schedules to avoid confusing normal foreground posting with export changes.
2. Inspect JSON and CSV previews. Cancel each preview and verify the source records and export controls remain usable.
3. Open Save to Files. Cancel from the actual visible system controls, both from Browse and inside a provider folder. Verify return to the preview without an export error. Do not rely on a hidden AX element or a coordinate over the More menu.
4. Save each format to On My iPhone, reopen it in Files, and verify it is nonempty and has the appropriate extension and contents. Check JSON format/version, ledger records, schedules, posting history and budgets. Check CSV date/money columns, Unicode, commas/quotes/newlines, and formula-like text handling in the intended spreadsheet application.
5. Repeat a save of each format in the same app session. If a cloud provider is configured by the tester, repeat saving/retrieval there; the app itself requires no cloud credentials.
6. Record actual pass/fail results and defects. No results are prefilled here. Restore/import is not shipped in this feature; these checks do not authorize deleting original app data.

Signing, release archives, App Store/TestFlight distribution and the decision to ship remain Amartya's responsibility.
