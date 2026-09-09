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
- [x] "Lines on the bottom" — resolved once a real (non-stale) screenshot
      showed the actual complaint: the divider line under each Ledger
      category row (`_CategoryRow`'s `Border(bottom: BorderSide(...))`).
      Removed entirely, per "remove the lines in categories". Implemented
      same session.
- [x] Add empty-state messaging wherever a screen currently has no data.
      `LedgerScreen` now shows "No categories yet — add one from the
      Budgets tab..." and "No transactions yet — scan a receipt or add
      one manually." in place of a blank card/section; `BudgetsScreen`
      shows "No categories yet — add one below..." above its existing
      "+ Add a category" button. (`CategoryDetailScreen` already had an
      empty state for a category with no transactions.) Implemented same
      session.
- [x] Add a native launch screen (like Airbnb's) — the app's logo centered
      on a plain background, shown instantly while the OS/Flutter engine
      boots, before the lock screen appears. Implemented: new
      `tool/generate_launch_image_test.dart` renders the Stub mark to
      1x/2x/3x PNGs for both `ios/Runner/Assets.xcassets/LaunchImage
      .imageset/` and Android's `drawable-nodpi/launch_image.png`;
      `LaunchScreen.storyboard` and both `launch_background.xml` variants
      updated to a `bgLight` (`#ECE7DC`) background with the mark
      centered at 240x240. No dark-mode variant yet (matches the plain-
      light-background reference screenshot) — could add one later via
      an iOS asset-catalog color set + Android `-night` resources if
      wanted. Not verified on a real device yet (a full launch-screen
      change needs a real cold app launch to see, not `flutter run`'s
      hot-reload path). Implemented same session.
- [x] Update how the CSV is exported — clarified: needed a way to specify
      what gets exported (which categories, which month), not always
      dumping every transaction ever. New `ExportDataScreen` (month
      dropdown + multi-select category chips) opens from Settings'
      "Export data" button; `RootShell._performExport` filters before
      calling `exportTransactionsCsv`. Implemented same session.
- [x] Add a max limit on the budget limit amount field (AddCategoryScreen)
      — capped at 1,000,000 (a sanity ceiling, not a technical limit;
      picked without explicit confirmation, easy to change). Blocks save
      with a snackbar if exceeded. Implemented same session.
- [x] Add a max character length on the category name field
      (AddCategoryScreen) — capped at 40 characters via `TextField
      .maxLength` (picked without explicit confirmation, easy to change).
      Implemented same session.
- [x] Cap the total number of categories a user can create at 30 — past
      that, `RootShell._openAddCategory` shows a snackbar instead of
      opening `AddCategoryScreen`. Implemented same session.
- [x] Limit Ledger's "RECENT" list to the 5 most recent transactions
      instead of showing all of them. `RootShell` now passes
      `data.transactions.take(5)` to `LedgerScreen.recent` (the full list
      is still used everywhere else — export, delete-all, category
      filtering). Implemented same session.
- [x] Add a Face ID/passcode on/off toggle in Settings — new
      `LocalPrefs.lockEnabled` (default `true`, so existing behavior is
      unchanged unless explicitly turned off) + a live `lockEnabledNotifier`
      threaded through `StubApp`, same pattern as theme/currency; the
      toggle is hidden entirely on a device with nothing enrolled. Found
      and fixed a real bug along the way: turning the lock off while
      sitting at the lock screen hid the overlay but left the home screen
      unbuilt (blank screen) since `_buildHome()` was gated on
      `_handleUnlock()` having run, not just the overlay being hidden —
      `_onLockEnabledChanged` now calls it when needed. Also renamed
      AddCategoryScreen's "Monthly limit" label to just "Limit" (the
      period picker already covers weekly/yearly/custom). Implemented
      same session.
- [x] Real weekly-summary notifications — the second (and bigger) of the
      two notification toggles. Fires roughly weekly (aimed at Sunday
      6pm, but iOS/Android background tasks are opportunistic — not an
      exact-time guarantee) with the real computed total spent + top
      category for that week, even if the app hasn't been opened. New
      `workmanager`-based `weekly_summary_scheduler.dart` (registers a
      periodic background task; its callback dispatcher re-initializes
      Supabase in a fresh isolate to fetch fresh data) + pure
      `util/weekly_summary.dart` logic (fully unit-tested). Settings'
      "Weekly summary" toggle now requests notification permission and
      registers/cancels the real task via a new `onWeeklySummaryToggled`
      callback (kept separate from direct `workmanager` calls since that
      package has no fake and can't run inside a widget test). iOS
      `Info.plist` updated with `UIBackgroundModes`
      (fetch/processing) + `BGTaskSchedulerPermittedIdentifiers`. Not yet
      verified on a real device — timing especially, since background
      task firing is inherently opportunistic on both platforms.
      Implemented same session.
- [x] Real budget-limit-warning notifications — first of the two
      notification toggles to get built (weekly summary is bigger, needs
      background scheduling, deferred). Fires a local notification at
      80%/90%/97%/100%/105% of a category's budget (once per tier per
      period, persisted via `LocalPrefs` so it survives app restarts and
      resets on period rollover). New `NotificationService` abstraction +
      `LocalNotificationsService` (`flutter_local_notifications`) +
      `FakeNotificationService`; pure threshold logic in
      `util/budget_thresholds.dart`; wired into `RootShell._load()` and
      gated on Settings' existing "Budget limit warnings" toggle, which
      now also requests the OS permission when turned on. Android's
      manifest updated with `POST_NOTIFICATIONS`. Not yet verified on a
      real device (needs a real platform channel, same as ML Kit/local_auth).
      Implemented same session.
- [x] "OVERALL isn't working" (still) — the real bug was never the display
      format (dollar vs. percentage), it was the calculation: total-spent
      ÷ total-limit weighted by budget size let one huge-limit,
      near-$0-spent category drag the combined figure toward 0% even
      with another category at 120%. Fixed by switching `RootShell
      ._overallFraction` to average each budgeted category's own
      fraction instead. Implemented same session, with an updated
      `root_shell_test.dart` case.
- [x] Redesign the OVERALL hero (was a confusing blended percentage) — first
      changed to real "$spent / $limit" dollar figures, then **reverted
      back to percentage** after real testing showed the dollar version
      looked worse in practice (huge numbers, and "change it" feedback
      once seen live); `StubHeroAmount.range` was added then removed
      again same session. `CategoryDetailScreen` still shows the
      established limit ("of $X limit") alongside its dollar total — that
      part stands. Also added ellipsis-truncation for long category names
      (Ledger/Budgets rows, `CategoryDetailScreen`'s app-bar title, now
      also colored by budget status on both, not just the percentage
      number) and shrink-to-fit (`FittedBox`) on `StubHeroAmount` for long
      amounts. Implemented same session.
- [x] Ledger's manual-entry FAB made bigger (60x60, was defaulting to
      Material's ~56dp regardless of intent) and its "+" icon recolored
      from a hardcoded white to `onAccentDark`/`onAccentLight` to match
      the theme, per feedback. Implemented same session.
- [x] Native launch screen: shrunk the logo (240 → 120 logical size) and
      made its background follow the app's light/dark theme instead of
      always being light, per feedback after seeing it on a real cold
      launch. Implemented same session (see `generate_launch_image_test
      .dart`'s entry in the file map).
- [x] Color the percentage/progress (category rows + the new combined
      OVERALL hero) based on proximity to the budget limit — include red
      when very close to or over budget. Implemented: new `BudgetStatus`
      enum (`lib/theme/budget_status.dart`, normal/warning/danger) drives
      flat amber/red overrides on the percentage text, `StubProgressBar`,
      `StubProgressRing`, and `StubHeroAmount.percent` everywhere a
      category or the combined OVERALL hero shows progress. Same session.
- [ ] User asked "can we do this?" about a screenshot of another app's
      Apple Pay auto-tracking feature (an iOS Shortcuts automation that
      fires on an Apple Pay transaction and saves an expense
      automatically, with "Automation instructions"/"Add to Shortcuts"
      setup buttons). This is a feasibility question, not yet scoped —
      will respond with a feasibility take once the amount-cap work below
      is done.
- [x] `StubLoadingIndicator`'s paper-ticket animation was hard to see in
      light mode (its fixed cream paper color sits too close to the light
      background). Fixed with a subtle fixed dark outline traced around
      the paper shape, visible against either theme. Implemented same
      session.
- [x] Raised the AddCategoryScreen limit cap from 1,000,000 to
      10,000,000,000, and added a `ThousandsSeparatorInputFormatter` that
      live-formats the limit field with commas as you type ("1000000" →
      "1,000,000"); `_save()` strips them back out before parsing.
      Extracted to `util/thousands_input_formatter.dart` and applied to
      `ManualEntryScreen`'s amount field too (same cap, same formatter),
      per follow-up feedback. Implemented same session, with regression
      tests for both screens plus the formatter itself.
- [x] Move the CURRENCY dropdown on `AddCategoryScreen` to the right side
      — now a `Row` with the "CURRENCY" label on the left and the
      `DropdownButton` on the right, instead of stacked. Implemented same
      session.
- [x] SOURCE field on `EditEntryScreen` was showing a date ("6/9") instead
      of the real source — was wired to `transaction.dateLabel` instead of
      the actual source. Fixed: real source label (`transactionSourceLabel`)
      restored, plus a new DATE row so the date isn't lost. Implemented
      same session, with a regression test in `root_shell_test.dart`.
