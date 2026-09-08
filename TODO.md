# Ad-hoc fixes / requests

Running scratch list for things mentioned mid-session, so nothing gets lost
while other work is in progress. Check items off (or delete the line) once
done; fold anything durable into `CLAUDE.md` instead of leaving it here.

- [x] Make sure the category limit/budget progress (Budgets tab) also
      updates immediately after a write — confirmed covered by the same
      fix below (it's applied at the shared `_ShellData`/`FutureBuilder`
      level `RootShell` uses for every tab, not Ledger-specific).
- [x] Values (e.g. "left to spend") not refreshing — resolved, the
      pull-to-refresh added earlier this session was in fact working; user
      confirmed after retrying.
- [x] Update immediately (no spinner flash) after adding a receipt/entry
      and returning to Home — found and fixed a real bug: every write
      triggered `RootShell._reload()`, which tore the whole screen down
      to a bare spinner while refetching, unmounting `LedgerScreen`'s
      `StubProgressRing` and making it restart its fill animation from
      zero each time. Now keeps showing the last-known data during a
      background reload and swaps in the new numbers once it lands, so
      the ring updates in place instead of resetting. Implemented same
      session.
- [x] Add pull-to-refresh to `BudgetsScreen` too, same as `LedgerScreen`
      (`RefreshIndicator` wired to `RootShell._handleRefresh`).
      Implemented same session.
- [x] User wants per-category currency (not one global app-wide currency
      as originally scoped/approved) — implemented: global default
      (`SettingsScreen`, persisted via `LocalPrefs.currencyCode`/
      `currencyNotifier`) + optional per-category override
      (`AddCategoryScreen`, `categories.currency_code`); mixed-currency
      totals just add raw numbers (no conversion), per instruction.
- [x] User then said "the total widget should be in each category
      actually" — implemented: the combined "left to spend"/"budgeted
      this month" heroes are gone from Ledger/Budgets (replaced by a
      per-category percentage-of-budget row), and the real dollar-amount
      hero now lives on `CategoryDetailScreen` (per category, in that
      category's own currency).
- [x] Add currency switching (display format) — done, see the two entries
      below (global default + per-category override, and the "add most
      currencies" broadening). Language switching (app UI) is a separate,
      still-open piece — full `intl`/ARB localization, only
      dependency/config scaffolding (`l10n.yaml`, pubspec deps) done so
      far; no ARB content or string extraction yet across the ~15 screens.
- [x] Make category rows tappable — show all transactions/receipts saved
      under that category. New `CategoryDetailScreen`; both
      `LedgerScreen`'s category rows AND `BudgetsScreen`'s budget rows
      open it via `RootShell._openCategoryDetail`, and tapping a
      transaction inside it opens the same `EditEntryScreen` correction
      flow used everywhere else. Implemented same session.
- [x] Fix the mismatch between "left to spend"/ring (period-scoped, from
      `budget_progress`) and the Ledger category rows (was all-time).
      Fixed: a category row now shows its budget's period-scoped `spent`
      (the same value driving the ring above) when it has a budget,
      falling back to an all-time sum only for a category with no budget
      at all. Implemented same session.

- [x] Add a manual refresh option in the app — pull-to-refresh on
      `LedgerScreen`, wired to `RootShell._handleRefresh`. Implemented
      same session.
- [x] Add a way to set the user's name (first + last name) — tappable
      name row at the top of `ProfileScreen`, stored via
      `AccountLinkService.setName` (Supabase auth user metadata).
      Implemented same session.
- [x] Investigate/fix the freeze when uploading a photo to scan — found
      the real cause: `normalizeImageOrientation` was decoding, baking
      orientation, and re-encoding a full-resolution JPEG synchronously
      on the main isolate (via the `image` package), which genuinely
      blocked the whole UI thread (including the spinner's own animation)
      for however long that took. Not shader jank, as originally
      suspected (this app runs Impeller, which doesn't have that problem)
      — fixed by moving the decode/bake/encode work into a background
      isolate via `compute()`. Implemented same session.
- [x] Add a scan-screen tip telling users to photograph the receipt flat
      and well-lit, for better OCR accuracy — implemented same session.
- [x] Redesign the loading screen/spinner — new `StubLoadingIndicator`
      (gradient-colored, matches the app's design language) replaces the
      default blue `CircularProgressIndicator` everywhere it was used.
      Implemented same session.
- [x] "Add most currencies" — `lib/util/currency.dart` now has a curated
      ~39-currency symbol map (`supportedCurrencies`); `SettingsScreen`'s
      global picker and `AddCategoryScreen`'s per-category override both
      switched from a 2-chip `Wrap` to a `DropdownButton` over that list.
      Implemented same session.
