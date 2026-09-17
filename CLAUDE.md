# Stub — Project Instructions

## Mid-task requests go in TODO.md — no exceptions

If the user asks for something while another task is already in progress,
it MUST be logged as a checklist item in `TODO.md` (repo root) before
continuing the current task. This is not optional and not a judgment call
— log it every time, even for something that sounds small, even if it
will clearly get picked up in the same session shortly after. Don't
silently context-switch to it and don't silently drop it either; write it
down first, say so in one line, then keep going on the current task
unless the user explicitly says to switch now.

## File map — check here before exploring/globbing the project

Everything not listed below is either generated boilerplate (Android/iOS
Flutter scaffold, `.dart_tool/`, `build/`, `Pods/`, `.symlinks/`) or a
one-off spike output — safe to ignore unless a task specifically concerns
it.

| Path | What's there |
|---|---|
| `CLAUDE.md` (repo root) | This file — process rules, decisions, status |
| `TODO.md` (repo root) | Ad-hoc mid-session fixes/requests scratch list — see "Mid-task requests" above |
| `DESIGN.md` (repo root) | The full visual spec — colors, type, gradient rules, icon library, logo geometry. Load before any visual change. |
| `mockups.html` (repo root) | The 7-screen HTML mockup, published as artifact "Stub" — the visual reference implementation |
| `logo-concepts.html` (repo root) | The 4 logo directions explored before picking torn-stub-+-check, published as artifact "Stub Marks" |
| `app/` | The real Flutter project root (`pubspec.yaml`, `lib/`, `ios/`, `android/`) |
| `app/lib/main.dart` | App entry point — Supabase init, theme wiring, gates on LockScreen, then (on first unlock only) the one-time `BackupPromptScreen`, before showing RootShell. `_startup()` also reads `LocalPrefs.currencyCode()` once, seeds `CurrencyConfig.code` with it, and builds the `currencyNotifier` (`ValueNotifier<String>`) threaded down through `StubApp` → `RootShell` → `SettingsScreen`, same pattern as `themeModeNotifier`; `_StubAppState` keeps `CurrencyConfig.code` in sync with that notifier for the life of the app via a listener added in `initState`/removed in `dispose`, since `CurrencyConfig` itself is a plain static field with no notification of its own. `_StubAppState` is also a `WidgetsBindingObserver`: it checks `DeviceAuthService.isSupported()` once at startup (skipping the lock screen entirely if the device has no biometric/passcode enrolled at all) and re-locks immediately (`_unlocked = false`) whenever the app backgrounds (`paused`/`hidden`), so resuming always requires re-auth. `_initWeeklySummary(localPrefs)` (best-effort — never blocks startup) calls `Workmanager().initialize(weeklySummaryCallbackDispatcher)` once, then re-registers the periodic task if `weeklySummaryEnabled()` is already true from a previous session (idempotent, cheap, protects against the OS having dropped the registration). `_startup()` also seeds a `lockEnabledNotifier` (`ValueNotifier<bool>`, from `LocalPrefs.lockEnabled()`) threaded down through `StubApp` → `RootShell` → `SettingsScreen`'s Face ID/passcode toggle; `_StubAppState.build()` wraps the lock-overlay `Stack` in a `ValueListenableBuilder<bool>` on it so toggling live (no restart needed) immediately shows/hides `LockScreen`. `_onLockEnabledChanged` (a listener added in `initState`/removed in `dispose`) calls `_handleUnlock()` if the toggle is turned off while `_unlocked` is still false — without this, disabling the lock while sitting at the lock screen hid the overlay but left `_buildHome()` rendering nothing (a real, confirmed bug: `_buildHome()`'s content is gated on `_handleUnlock()` having run, not just on the overlay being hidden). `_StubAppState` also takes a `deepLinkService: DeepLinkService` and listens for incoming `com.stubapp.stub://log-expense` Siri Shortcuts deep links (see `util/deep_link.dart`, `data/deep_link_service.dart`): `_listenForDeepLinks()` checks `getInitialLink()` (cold launch) then subscribes to `onLink` (warm), both wrapped so a platform-channel failure never blocks startup; `_handleIncomingLink` holds the parsed link as a single nullable `ParsedDeepLink? _pendingLink` plus a monotonically-increasing `int _deepLinkSerial` (bumped only when a link is actually accepted) — **deliberately never cleared**, since an earlier version that cleared it via `addPostFrameCallback` right after building `RootShell` raced against `RootShell`'s own async data load and could zero it out before `RootShell` ever got a chance to consume it (a real, confirmed bug, caught by a whole-branch review after all 7 individual tasks had already passed their own). `_buildHome()` passes both through to `RootShell` as `initialManualEntryLink` and `initialManualEntryToken: _pendingLink == null ? null : _deepLinkSerial` — the token (not a plain bool) is what lets `RootShell` tell "a genuinely new link just arrived" apart from "the same already-consumed link is still sitting in state after an unrelated rebuild" (tab switch, pull-to-refresh), so a second, different Shortcuts run later in the same app session still works instead of being silently dropped |
| `app/lib/theme/colors.dart` | Every color token, copied from DESIGN.md §2 — never invent a color elsewhere; includes `phoneBodyLight`/`phoneBodyDark` (DESIGN.md's `--phone-body`), `LockScreen`'s always-dark bezel — still theme-reactive like every other token (warm `#1B1712` in light, neutral near-black `#050505` in dark), just always dark either way |
| `app/lib/theme/text.dart` | The 3-font system (Archivo/Domine/Unbounded) from DESIGN.md §1 |
| `app/lib/theme/app_theme.dart` | Wires colors.dart + text.dart into Flutter's light/dark ThemeData |
| `app/lib/config/supabase_config.dart` | Supabase URL + publishable key (client-safe; never put a secret key here) |
| `app/lib/models/transaction.dart` | `Transaction`, `TransactionSource` — transaction model; now also carries `categoryId`, `fromRow`/`toInsertRow` (Postgres row mapping), and `copyWith`; top-level `transactionSourceLabel(source)`/`transactionDateLabel(occurredAt)` (also exposed as `Transaction.sourceLabel`/`.dateLabel` getters) back `EditEntryScreen`'s SOURCE/DATE rows — shared functions so the scan-create flow (no `Transaction` yet, just a raw `source`/`occurredAt`) and the edit-existing flow both use the same labels |
| `app/lib/models/category_spend.dart` | `CategorySpend` — per-category dashboard row; carries `categoryId` (so a tapped row can be routed to `CategoryDetailScreen`), a nullable `fraction` (0.0-1.2, matching `BudgetLimit.fraction`) instead of a dollar `amount` — null means "no budget set", the fallback shown on Ledger/Budgets rows instead of a percentage — plus the resolved `color` and the category's `icon` key (into `category_icons.dart`) for rendering the row's tinted icon |
| `app/lib/models/budget_limit.dart` | `BudgetLimit`, `BudgetPeriodType` (weekly/monthly/yearly/custom) — budget cap per category, `fromRow` maps a `budget_progress` view row; also carries `icon` (default `'tag'`) and nullable `colorIndex`, joined in from the category via that view, so `BudgetsScreen` rows can render the same icon/color as Ledger without a second query; `isWarning` (>=90%, unchanged), new `isOverBudget` (>=100%) and `status` (a `BudgetStatus`, see `theme/budget_status.dart`) back the red/amber color-by-proximity treatment |
| `app/lib/theme/budget_status.dart` | `BudgetStatus` enum (`normal`/`warning`/`danger`), `budgetStatusForFraction(fraction)` (null-safe — a category/hero with no budget is always `normal`), `budgetStatusColor(status, brightness)` (null for `normal` — caller keeps its own default styling; `--warn` amber / `--danger` red flat colors for the other two, extending DESIGN.md's existing "a warning shouldn't be dressed up decoratively" rule to a new over-budget tier). Backs the percentage-text/progress-bar/progress-ring/hero-number coloring on Ledger, Budgets, and Category Detail |
| `app/lib/models/category.dart` | `Category` — id/name, plus an optional `currencyCode` (overrides the app's global default currency for just this category's amounts; null means "use the default"), `icon` (key into `category_icons.dart`'s curated set, default `'tag'`), nullable `colorIndex` (index into `category_colors.dart`'s swatch palette — null only for a category created before color picking existed), `fromRow`/`toInsertRow` (`currency_code`/`icon`/`color_index` columns) |
| `app/lib/theme/category_colors.dart` | `categoryColor(index, brightness)` — deterministic 6-color swatch cycle for category rows, light/dark palettes; `categoryColorCount` (6, how many swatches the color picker offers); `categoryColorIndexFor(categoryId, stored)` — a category's explicit `colorIndex` pick, or a deterministic id-hash fallback slot for legacy categories created before color picking existed |
| `app/lib/theme/category_icons.dart` | `categoryIconKeys` (the ordered ~16-key list `AddCategoryScreen`'s icon picker iterates, `'tag'` first as the generic default) and `categoryIconData(key)` — maps a category's `icon` key to its raw SVG data in `StubIcons`, falling back to the tag icon for any unrecognized/legacy value |
| `app/lib/data/category_repository.dart` | `CategoryRepository` — abstract interface; `list`/`delete`, and `create(name, {currencyCode, icon, colorIndex})` for the optional per-category currency override and the chosen icon/color |
| `app/lib/data/transaction_repository.dart` | `TransactionRepository` — abstract interface (`list`/`create`/`update`/`delete`) |
| `app/lib/data/budget_repository.dart` | `BudgetRepository` — abstract interface (`list`/`create`) |
| `app/lib/data/fakes.dart` | `FakeCategoryRepository`, `FakeTransactionRepository`, `FakeBudgetRepository`, `FakeTextRecognitionService`, `FakeDeviceAuthService`, `FakeNotificationService` — in-memory test doubles. `FakeBudgetRepository` takes an *optional* `FakeCategoryRepository` link: when given, it resolves real category names **and icon/colorIndex** on `create()` and drops budgets from `list()` once their category is gone (mirroring the schema's `ON DELETE CASCADE`); without it, falls back to a placeholder name/`'tag'` icon and no cascade — a deliberate, non-naive design, not a plain in-memory store. `FakeTextRecognitionService` just returns a configured `List<RecognizedLine>` from `recognizeText` — no OCR. `FakeDeviceAuthService` takes `supported`/`succeeds` flags — no real biometric check. `FakeNotificationService` takes a `permissionGranted` flag, tracks whether `requestPermission()` was ever called (`permissionRequested`), and records every `show()` call in `shown` |
| `app/lib/data/text_recognition_service.dart` | `TextRecognitionService` — abstract interface (`recognizeText(imagePath) -> List<RecognizedLine>`); `RecognizedLine` carries recognized `text` + its `boundingBox`, enough for `receipt_parser.dart`'s position-based reconstruction |
| `app/lib/data/mlkit_text_recognition_service.dart` | `MlKitTextRecognitionService` — real `TextRecognitionService` via `google_mlkit_text_recognition`; flattens every block/line into `RecognizedLine`s, closes the recognizer in a `finally` |
| `app/lib/data/supabase_category_repository.dart` | `SupabaseCategoryRepository` — real Postgres-backed `CategoryRepository` via `supabase_flutter`; `create` inserts `currency_code`, `icon`, and `color_index` |
| `app/lib/data/supabase_transaction_repository.dart` | `SupabaseTransactionRepository` — real Postgres-backed `TransactionRepository`; joins `categories(name)` on read |
| `app/lib/data/supabase_budget_repository.dart` | `SupabaseBudgetRepository` — real Postgres-backed `BudgetRepository`; reads from the `budget_progress` view |
| `app/lib/data/local_prefs.dart` | `LocalPrefs` — thin wrapper around `SharedPreferences` for local, per-device UI prefs (never financial data); the one-time `has_seen_backup_prompt` flag, `themeMode`/`setThemeMode` (persisted `ThemeMode`, defaults to `system`), `currencyCode`/`setCurrencyCode` (defaults `'USD'`, the app's global display-currency default) and `localeCode`/`setLocaleCode` (defaults `null` = system locale — scaffolding for the still-unstarted language work, not yet read anywhere), `budgetWarningsEnabled`/`setBudgetWarningsEnabled` (default `true`, now real — see `notification_service.dart`) + `weeklySummaryEnabled`/`setWeeklySummaryEnabled` (default `true`, still UI-only), `notifiedThresholdFor`/`setNotifiedThresholdFor(categoryId, periodStart, threshold)` — the highest budget-notification threshold (see `util/budget_thresholds.dart`) already fired for a category within its current budget period, JSON-encoded under one `SharedPreferences` key, keyed by `'$categoryId:${periodStart.toIso8601String()}'` so a new period starts fresh automatically — and `lockEnabled`/`setLockEnabled` (default `true`, so nothing changes for existing users unless they explicitly turn off Face ID/passcode in Settings). Concrete class, not an interface — no fake exists for it (see `app/test/widget_test.dart`'s `_ThrowingSharedPreferencesStore` for how a real failure is forced through it in tests instead) |
| `app/lib/data/notification_service.dart` | `NotificationService` — abstract interface (`requestPermission()`, `show({title, body})`) for local (on-device, non-push) notifications; currently used for real-time budget-threshold alerts, written to be reused by a future weekly-summary notification too |
| `app/lib/data/local_notifications_service.dart` | `LocalNotificationsService` — real `NotificationService` via the `flutter_local_notifications` package (v22 API — named parameters throughout, e.g. `initialize(settings: ...)`/`show(id:, title:, body:, notificationDetails:)`); `requestPermission()` resolves the iOS or Android platform-specific plugin implementation and calls its own permission request. No automated test — needs a real platform channel, same story as `MlKitTextRecognitionService`/`LocalAuthDeviceAuthService`; verify manually. Android needs `POST_NOTIFICATIONS` declared in `AndroidManifest.xml` for the runtime request to work on API 33+ |
| `app/lib/util/budget_thresholds.dart` | `budgetNotificationThresholds` (`[0.80, 0.90, 0.97, 1.00, 1.05]`, picked directly per user request), `highestNewlyCrossedThreshold(fraction, alreadyNotified)` (the highest tier newly reached — a transaction that jumps a category straight from 70% to 110% fires once, at 105%, not all five tiers in a row), and `budgetThresholdMessage(categoryName, threshold)` (the notification body). Pure, fully unit-tested |
| `app/lib/util/weekly_summary.dart` | `WeeklySummary` (total spent + whichever category spent the most, that week), `computeWeeklySummary(transactionsInWeek)` (null for an empty week — caller skips notifying), `weeklySummaryMessage(summary)` (the notification body, e.g. "You spent $342 this week. Groceries was your biggest category at $118."). Pure, fully unit-tested — the caller is responsible for filtering to the target week first |
| `app/lib/data/weekly_summary_scheduler.dart` | `scheduleWeeklySummary()`/`cancelWeeklySummary()` (register/cancel a periodic `workmanager` task, idempotent by unique name), and `weeklySummaryCallbackDispatcher()` — the top-level `@pragma('vm:entry-point')` function `Workmanager().initialize()` points at, which runs in a fresh background isolate with none of the running app's state: re-initializes Supabase from scratch (the persisted session restores automatically, same as a normal cold start), queries the last 7 days of transactions directly via the Supabase client (no repository — there's no injected one in a background isolate), computes the summary, and shows it via `LocalNotificationsService`. `initialDelay` only aims the *first* fire at the next Sunday 6pm local time — neither iOS `BGTaskScheduler` nor Android `WorkManager` guarantee exact-clock-time firing on a periodic task after that; the OS runs it opportunistically based on device usage/battery/charging state (a real, accepted platform constraint, not a bug — see Open Items). No automated test — needs a real background execution environment; verify manually. The task identifier (`com.stubapp.stub.weeklySummary`) must stay in sync with `ios/Runner/Info.plist`'s `BGTaskSchedulerPermittedIdentifiers` entry |
| `app/lib/data/device_auth_service.dart` | `DeviceAuthService` — abstract interface (`isSupported()`, `authenticate()`) gating the app behind the device's own biometric/passcode lock |
| `app/lib/data/local_auth_device_auth_service.dart` | `LocalAuthDeviceAuthService` — real `DeviceAuthService` via the `local_auth` package; `authenticate()` calls `LocalAuthentication.authenticate(biometricOnly: false)`, letting the OS fall back from biometric to passcode itself; no automated test (needs a real platform channel, same story as `MlKitTextRecognitionService`) |
| `app/lib/data/account_link_service.dart` | `AccountLinkService` — abstract interface (`isAnonymous`, `linkedEmail`, `memberSince`, `firstName`, `lastName`, `linkEmail(email)`, `setName({firstName, lastName})`, `linkStatusChanges` stream) for linking a persistent identity onto the anonymous session; `memberSince` backs `ProfileScreen`'s "Member since" line; `firstName`/`lastName`/`setName` back its tappable name row |
| `app/lib/data/supabase_account_link_service.dart` | `SupabaseAccountLinkService` — real `AccountLinkService` via `supabase_flutter`'s `auth.updateUser`; `linkEmail` sets `emailRedirectTo: 'com.stubapp.stub://login-callback'`; `firstName`/`lastName` read from `currentUser.userMetadata`, `setName` writes both via `UserAttributes(data: {...})` — note this **replaces** the whole `user_metadata` map rather than merging, harmless today since name is the only metadata this app sets |
| `app/lib/widgets/stub_button.dart` | `StubButton` — Add/Save variant button, see Component inventory below |
| `app/lib/widgets/stub_logo.dart` | `StubLogo` — the torn-stub-+-check mark, DESIGN.md §7 |
| `app/lib/widgets/stub_icon.dart` | `StubIcon`, `StubIcons` — recolorable Tabler SVG icon widget; `StubIcons` holds the original 14 icons (home, camera, chartBar, userCircle, receipt, cashBanknote, buildingBank, lock, pencil, x, mail, brandApple, brandGoogle, phone) used across nav, close buttons, screens, and the account-link provider rows, plus 16 category icons (tag, cart, car, home, heart, film, bag, coffee, plane, book, bolt, dumbbell, paw, gift, phone, wallet — see `category_icons.dart` for the key mapping the picker/display actually uses) |
| `app/lib/widgets/stub_card.dart` | `StubCard` — reusable card surface for dashboard, category rows, transaction tiles |
| `app/lib/widgets/stub_chip.dart` | `StubChip` — category filter chip with active/gradient state |
| `app/lib/widgets/stub_field_row.dart` | `StubFieldRow` — label + value pair, used in Edit Entry and Manual Entry screens |
| `app/lib/widgets/stub_progress_ring.dart` | `StubProgressRing` — circular progress ring, shared between dashboard hero and widget; optional `status` (`BudgetStatus`, default `normal`) swaps the gradient stroke for a flat warn/danger color, same rule `StubProgressBar` follows |
| `app/lib/widgets/stub_progress_bar.dart` | `StubProgressBar` — linear progress bar; legacy `isWarning` bool constructor kept for back-compat, new `StubProgressBar.status(progress, status)` constructor takes a `BudgetStatus` directly to also support the `danger` (over-budget, flat red) tier alongside the existing `warning` (flat amber) one |
| `app/lib/widgets/stub_transaction_tile.dart` | `StubTransactionTile` — list row for a single transaction (icon, description, amount, date) |
| `app/lib/widgets/stub_bottom_nav.dart` | `StubBottomNav`, `StubNavItem` — bottom navigation bar with 3 tabs (Home/Budgets/Profile) + a separate fixed round scan button (not one of the 3 tabs) |
| `app/lib/widgets/stub_hero_amount.dart` | `StubHeroAmount` — big gradient-text currency number (`ShaderMask` + `StubColors.gradPop`), used for every hero amount so blue never renders flat there; always wrapped in a shrink-to-fit `FittedBox` so a long figure scales its font down instead of overflowing. `StubHeroAmount.percent(fraction, {flatColor})` shows a percentage instead (Ledger's OVERALL hero, category rows conceptually). `flatColor` (a `budgetStatusColor` result) replaces the gradient wipe with a plain fade-in in that color for the warn/danger states, same "no decorative gradient during a warning" rule as `StubProgressBar`. (A `.range(spent, limit)` "$X / $Y" variant was added, used, then removed same session — see `ledger_screen.dart`'s entry for why.) |
| `app/lib/widgets/stub_loading_indicator.dart` | `StubLoadingIndicator` — custom branded loading animation: a small paper ticket "prints out" of a slot (torn zigzag bottom edge, a `gradPop` gradient accent stripe, faint printed-line texture), looping via `AnimationController.repeat(reverse: true)` and a `CustomPainter` (`_ReceiptPrinterPainter`); replaces Flutter's default blue `CircularProgressIndicator` everywhere the app shows an indeterminate loading state. (Superseded an earlier gradient-`ShaderMask`-ring version, same session, per user request for something more custom/on-theme.) The ticket's fixed cream paper color (`_paper`) sits too close to the light theme's background to read as a distinct shape there — fixed with a subtle fixed dark outline (`_slot` at 35% alpha) traced around the paper's path, visible against either theme |
| `app/lib/widgets/stub_pressable.dart` | `StubPressable` — press feedback (scale+fade) wrapper for tappable widgets, with an optional 44x44 minimum tap-target guarantee; used instead of `InkWell` since most tappable surfaces here have an opaque gradient/solid fill that would hide a Material ripple |
| `app/lib/widgets/stub_period_picker.dart` | `StubPeriodPicker` — weekly/monthly/yearly/custom period selector (built from `StubChip` + `StubFieldRow`); shows start/end date fields (via `showDatePicker`) only when Custom is selected |
| `app/lib/widgets/stub_provider_row.dart` | `StubProviderRow` — one tappable provider row (icon + label + "Coming soon" tag when disabled); disabled rows are wrapped in `IgnorePointer` (absorbs taps instead of letting them fall through to a sibling) and `Semantics(enabled: false)` |
| `app/lib/widgets/stub_account_link_panel.dart` | `StubAccountLinkPanel` — the 4-provider linking UI (Email functional via `AccountLinkService.linkEmail`, Apple/Google/Phone visibly disabled), with its own email sub-flow, client-side validation, submit-guard, and friendly error handling; shared between `BackupPromptScreen` and Profile's future Account section — reuse it there, don't re-implement |
| `app/lib/util/currency.dart` | `CurrencyConfig.code` (deliberately global mutable state — the app's current display-currency default, kept in sync with `currencyNotifier` by `main.dart`), `supportedCurrencies` (curated ~39-code list backing both `SettingsScreen`'s global picker and `AddCategoryScreen`'s per-category override — the two can't drift apart since both read this same list), and `formatCurrency(amount, {currencyCode})` — shared thousands-separator currency formatter (negative-safe); an explicit `currencyCode` (e.g. a category's own override) takes precedence over `CurrencyConfig.code` for just that call. Real conversion is out of scope — this is display-symbol-only, and mixed-currency totals elsewhere in the app just add raw numbers |
| `app/lib/util/csv_export.dart` | `buildTransactionsCsv` (pure, unit-tested — `Date,Merchant,Amount,Category,Source` rows, quote-escaping via `_csvField`; the caller — `RootShell._performExport` — filters the transaction list by month/category before this ever sees it, via `ExportDataScreen`'s picker) and `exportTransactionsCsv` (writes the CSV to a temp file via `path_provider` and hands it to the OS share sheet via `share_plus`'s `SharePlus.instance.share`; not unit-tested — real I/O, verify manually) |
| `app/lib/util/receipt_parser.dart` | `ParsedReceipt` (nullable `merchant`/`amount`/`occurredAt` — every field is a best-effort guess, always routed through `EditEntryScreen` for human review, never auto-saved) and `parseReceiptLines(List<RecognizedLine>, {knownMerchants, source}) -> ParsedReceipt`: row-clusters lines by Y position then sorts each row left-to-right (`_reconstructRows`, the OCR spike's validated technique), redacts any 8+ digit run to `••••<last4>` via `redactLongDigitRuns` (applied unconditionally before extraction); amount detection joins each row's texts into one string before matching (`rowTexts`) — needed because a label like "TOTAL:" and its number are frequently OCR'd as two separate text blocks even on the same printed row, and searching them unjoined silently falls back to the largest number anywhere on the receipt (often the cash tendered, not the total); which bilingual (English/Spanish) keyword set counts as "total-style" depends on `source` (defaults to `TransactionSource.receipt`) — receipts/bank screenshots use `_receiptTotalKeywordPattern` (total, amount due, a pagar), payment-app scans use the broader `_paymentAppKeywordPattern` (total, monto, amount, enviado/enviaste, pagado/pagaste, sent, paid), since those confirmation screens often skip the word "total" entirely; date extraction (`_parseDate`) validates month 1-12/day 1-31 before accepting a match, rejecting false positives like a reference-number line ("13-2-1520258") that fits the MM-DD-YYYY shape but has an invalid month; merchant is the first non-empty (already-redacted) line, corrected to a `knownMerchants` entry (merchant names from past transactions, passed in by `RootShell`/`ScanScreen`) when a line scores >= 0.5 on a case-insensitive normalized-Levenshtein similarity (`_similarity`/`_levenshtein`) against one, checked only among the first 5 non-empty lines |
| `app/lib/util/image_orientation.dart` | `normalizeImageOrientation(String imagePath) -> Future<String>` — bakes any EXIF orientation into the pixel data (via the `image` package's `bakeOrientation`) and writes an upright JPEG, returning its path; falls back to the original path unchanged on any read/decode failure. ML Kit's text recognizer reads raw pixel buffers directly and does not reliably apply EXIF orientation itself, so a receipt photographed in portrait (very common) could otherwise be processed rotated — this was a real, confirmed root cause of both wrong totals and garbled merchant names on rotated captures (row-clustering assumes upright text). The decode/bake/encode work runs via `compute()` (`_bakeOrientationSync`, a top-level function) in a background isolate — doing this synchronously on the main isolate for a full-resolution photo was a real, confirmed cause of the app freezing (including the loading spinner's own animation) during a scan. Called from `ScanScreen._continue` before `TextRecognitionService.recognizeText` |
| `app/lib/screens/root_shell.dart` | `RootShell` — top-level navigation shell; takes `accountLinkService`, `themeModeNotifier` (`ValueNotifier<ThemeMode>`, read at startup from `LocalPrefs.themeMode()` and written live by `SettingsScreen`), `currencyNotifier` (same live-write pattern, for the global default currency — passed straight through to `SettingsScreen`), `localPrefs`, and `textRecognitionService` in addition to the three repositories; `_fractionFor(data, categoryId)` (a category's budget's `fraction`, or null if it has none), `_overallFraction(data)` (the average of every budgeted category's own fraction, unweighted by budget size — a real, confirmed problem with the earlier weighted-by-size version: a huge-limit, low-spend category could drag the combined figure toward 0% even when another category was well over its own budget; null if no category has a budget, feeding `LedgerScreen.overallFraction`) and `_currencyCodeFor(data, categoryId)` (that category's `currencyCode` override, or null for the default) back both the Ledger/Budgets percentage rows and `CategoryDetailScreen`'s hero; loads real data from its three injected repositories (`categoryRepository`/`transactionRepository`/`budgetRepository`) via a `FutureBuilder` (`_load`/`_reload`, with loading and error+retry states), tab-switches LedgerScreen/BudgetsScreen/ProfileScreen via StubBottomNav (cross-fades between them via `AnimatedSwitcher`), and pushes ScanScreen/EditEntryScreen/ManualEntryScreen/AddCategoryScreen/SettingsScreen/CategoryDetailScreen via Navigator.push; `build()`'s `FutureBuilder` keeps a `_lastData` cache and renders it (instead of a bare `StubLoadingIndicator`) whenever a reload is in flight but prior data exists — a write always triggers `_reload()` via `_guardedWrite`, and unconditionally tearing the screen down to a spinner on every single one of those was a real, confirmed bug: it unmounted `LedgerScreen`'s `StubProgressRing` each time, making the ring visibly restart its fill animation from zero after every write instead of updating in place; a background-reload failure with `_lastData` present now silently keeps the last-known-good data rather than showing the hard error screen (that's now reserved for a true first-load failure with no data at all); Ledger's per-category rows (`_spentFor`) show a category's budget's period-scoped `spent` when it has one — matching the same value driving "left to spend"/the ring, since these used to disagree (category rows summed *all* transactions ever regardless of budget period, while the ring only counts the current period) — falling back to an all-time transaction sum only for a category with no budget at all; `_openCategoryDetail(categoryId, categoryName, data, brightness)` pushes `CategoryDetailScreen` pre-filtered to that category's transactions plus its resolved `icon`/`color` (via `categoryColorIndexFor`), wired from both `LedgerScreen.onCategoryTap` and `BudgetsScreen.onCategoryTap`, and reuses `_openEditEntry` for its tap-through so correcting an entry from there works the same as everywhere else; `brightness` is computed once near the top of `build()` (needed by `CategorySpend`'s resolved color too) and threaded through rather than re-read per call site; `_openScan(transactions)` pushes `ScanScreen` wired to a real `TextRecognitionService` and a `knownMerchants` list (distinct merchant names from `transactions`, for OCR correction — see `scan_screen.dart`'s entry above), and `_handleScanned`/`_openScanCreateFlow` take its `ParsedReceipt` result into `EditEntryScreen(isCreating: true, ...)` pre-filled with the parsed merchant/amount and a real `TransactionRepository.create` on save (or a snackbar telling the user to add a category first, if none exist yet) — `_handleScanned` guards with `mounted` and `Navigator.canPop()` before popping, since `ScanScreen` can fire `onScanned` after it's already popped itself (user closed it mid-OCR), and a second unconditional pop would pop `RootShell`'s own route instead; `_openSettings` wires `SettingsScreen.onExportData` to `_openExportData` (fetches the full transaction list via `_fetchAllTransactions`, then pushes `ExportDataScreen`; `_performExport(transactions, month, categoryNames)` filters by both before calling `exportTransactionsCsv` — try/catch around that, snackbar on failure, pops back to Settings on success — not a Postgrest call so it bypasses `_guardedWrite`) and `onDeleteAllData` to `_deleteAllData` (a blocking, non-dismissible `CircularProgressIndicator` dialog while it loops `list()`-then-`delete()` on transactions until the list comes back empty — correct past PostgREST's 1000-row `max_rows` cap — then deletes every category, pops the dialog and Settings, and reloads); category deletion (both the Budgets-tab delete button and delete-all-data) surfaces the Postgres `ON DELETE RESTRICT` error (code `23503`) as a snackbar instead of crashing; `_openAddCategory(categories)` enforces a soft `_maxCategories` cap (30 — generous for real budgets, catches a runaway list) by showing a snackbar instead of pushing `AddCategoryScreen` once reached; `_load()` fires `_checkBudgetNotifications(data)` (fire-and-forget — never blocks or breaks rendering) after every load, initial and post-write alike — gated on `LocalPrefs.budgetWarningsEnabled()`, it checks each budget against `budgetNotificationThresholds`, and for the highest newly-crossed tier (via `highestNewlyCrossedThreshold`, comparing against `LocalPrefs.notifiedThresholdFor`) persists that tier and fires one `notificationService.show(...)` call, so re-loading (e.g. pull-to-refresh) never re-fires an already-notified tier; `RootShell` also takes optional `initialManualEntryLink`/`initialManualEntryToken` params (set by `StubApp` from a Siri Shortcuts quick-log deep link — see `main.dart`'s entry above); `_consumedManualEntryToken` (alongside `_lastData`) is compared against the incoming token (not a plain bool) so `build()` fires exactly one `WidgetsBinding.instance.addPostFrameCallback`-deferred call to `_openManualEntry` (immediately after the `if (data == null) {...}` early-return, guarded by `mounted`) per genuinely new/distinct link, while a rebuild that hands back the same already-consumed token (tab switch, pull-to-refresh) still doesn't re-open it; `_openManualEntry` itself now takes optional `{double? initialAmount, String? initialMerchant}` and threads them straight into `ManualEntryScreen`'s own pre-fill params |
| `app/lib/screens/ledger_screen.dart` | `LedgerScreen` — `overallFraction` (combined spent÷limit across every budgeted category, computed by `RootShell._overallFraction`; null when no category has a budget) drives an OVERALL hero card at the top (omitted when null) — `StubHeroAmount.percent` + `StubProgressRing`, both colored via `budgetStatusForFraction`/`budgetStatusColor` (flat amber/red once near or over budget, same as the per-category rows below); a dollar-figure ("$spent / $limit") version was tried and reverted back to percentage per feedback after real testing — it read as misleadingly close to 0% when one category's limit dwarfs the others (see `StubHeroAmount`'s now-removed `.range` constructor, no longer needed); per-category spend list shows the category's icon (`categoryIconData`, tinted in its resolved `color` — replaced the old plain color dot), an ellipsis-truncated name (`Expanded`/`maxLines: 1`, colored via `budgetStatusColor` same as the percentage next to it — not just the number), then `'${(fraction*100).round()}%'` of that category's budget or `'No budget set'` when `fraction` is null, each row tappable via `onCategoryTap` → `CategoryDetailScreen` (no divider line between rows — removed per feedback that it read as visual clutter) — an empty-state message ("No categories yet — add one from the Budgets tab...") replaces the card's content when `categories` is empty; recent transactions below, capped to the 5 most recent (`RootShell` passes `data.transactions.take(5)`; the full list is still used everywhere else — export, delete-all, category filtering); the manual-entry FAB is a plain `StubPressable`+`Container` (not a Material `FloatingActionButton`, which silently forces its own ~56dp footprint regardless of child size) at 60x60, `Icons.add` sized 30 and colored via `onAccentDark`/`onAccentLight` instead of a hardcoded white, both per feedback that the default felt small and off-theme; wrapped in a `RefreshIndicator` (`onRefresh`, wired to `RootShell._handleRefresh`) for pull-to-refresh, since data otherwise only reloads after a write; an empty-state message ("No transactions yet — scan a receipt or add one manually.") replaces the RECENT list when `recent` is empty |
| `app/lib/screens/category_detail_screen.dart` | `CategoryDetailScreen` — every transaction saved under one category: an app-bar title row with the category's tinted icon next to its ellipsis-truncated name (`icon`/`color`, required params passed by `RootShell`; name wrapped in `Flexible`+ellipsis so a long one can't overflow the `AppBar`), then a `StubHeroAmount`/`StubProgressRing` pair (the real dollar total in that category's own `currencyCode`, plus its budget `fraction` as a ring, colored via `budgetStatusForFraction` same as everywhere else — this is where the combined dashboard hero moved to, one category at a time, per the Ledger/Budgets percentage redesign) — a `limit` param (the category's actual established budget limit, from `RootShell`) shows as a small "of $X limit" line under the total when the category has a budget, so the real number you set is visible here even though the category-row list only shows a percentage — then a `StubTransactionTile` list or an empty state; reachable by tapping a category row on `LedgerScreen` or a budget row on `BudgetsScreen`; tapping a transaction inside it opens the same `EditEntryScreen` correction flow via `RootShell._openEditEntry` |
| `app/lib/screens/scan_screen.dart` | `ScanScreen` — real capture flow: the source picker shows a tip ("lay it flat on a well-lit surface and fill the frame") before the user picks a source (`image_picker`, camera or photo library; a picker/permission failure or a cancelled pick shows a snackbar and calls `onClose`), pick an image type (Receipt/Payment app/Bank screenshot via `StubChip`, mapped to `TransactionSource`), then runs `normalizeImageOrientation` (bakes in EXIF rotation before OCR — see `image_orientation.dart`'s entry above) + `TextRecognitionService.recognizeText` + `parseReceiptLines(lines, knownMerchants: widget.knownMerchants, source: source)` (any OCR failure is caught and falls back to an all-null `ParsedReceipt` rather than crashing) and calls `onScanned(parsed, source)` — no longer a hardcoded confirm-card. `knownMerchants` (merchant names from past transactions, supplied by `RootShell`) lets `parseReceiptLines` correct a noisy OCR read to a name already used; `source` selects which bilingual keyword set `parseReceiptLines` uses for total detection. `debugInitialImagePath` is a test-only seam (real `image_picker` results can't be faked in a widget test) that skips straight to the type-picker stage with a given path so the OCR/parse/`onScanned` wiring past image capture is still testable |
| `app/lib/screens/edit_entry_screen.dart` | `EditEntryScreen` — correct/review transaction details (merchant, amount, category, date, source); merchant and amount are genuinely editable (each opens an `_EditFieldDialog` text-entry dialog — fixed a pre-existing bug where the fields looked editable via `StubFieldRow(editable: true)` but had no `onTap` wired to change them) and saves/deletes via `TransactionRepository` through `RootShell`; `isCreating` (default `false`) hides the Delete row for the scan/manual-entry creation flow, where there's nothing yet to delete; DATE and SOURCE are both read-only rows (`dateLabel`/`sourceLabel`, from `transaction.dart`'s shared label helpers) — fixed a real bug where SOURCE was wired to `transaction.dateLabel` instead of the actual source, silently showing a "M/D"-shaped date (e.g. "6/9") where "Manual"/"Receipt scan"/etc. belonged; still no camera/re-capture feature |
| `app/lib/screens/manual_entry_screen.dart` | `ManualEntryScreen` — manual transaction entry form; now reachable from `LedgerScreen`'s FAB (see Open items — the "no UI trigger" gap is resolved) and writes via `TransactionRepository`; its amount field shares `AddCategoryScreen`'s live comma-formatting (`ThousandsSeparatorInputFormatter`) and the same `_maxAmount` (10,000,000,000) sanity cap, blocking save with a snackbar if exceeded; also takes optional `initialAmount`/`initialMerchant` (`double?`/`String?`, both null on every entry point except a Siri Shortcuts quick-log deep link — see `RootShell`'s entry above) that pre-fill `_amountController`/`_merchantController` on construction |
| `app/lib/util/thousands_input_formatter.dart` | `ThousandsSeparatorInputFormatter` — a `TextInputFormatter` that live-inserts thousands commas into a numeric field as you type ("1000000" → "1,000,000", preserving cursor position and a single decimal point); callers strip the commas back out (`.replaceAll(',', '')`) before parsing. Shared by `AddCategoryScreen`'s limit field and `ManualEntryScreen`'s amount field |
| `app/lib/util/deep_link.dart` | `ParsedDeepLink` (nullable `amount`/`merchant`) and `parseDeepLink(Uri) -> ParsedDeepLink?` — pure parsing of a `com.stubapp.stub://log-expense?amount=...&merchant=...` Siri Shortcuts quick-log link; null for any other host/scheme (e.g. the existing `login-callback` auth link) so callers just ignore those; a malformed/missing `amount` still returns a `ParsedDeepLink` (with `amount: null`) rather than failing, since `ManualEntryScreen` falls back to its own `$0.00` default in that case. Fully unit-tested, no platform channel needed — same pure/platform split as `receipt_parser.dart`/`csv_export.dart` |
| `app/lib/data/deep_link_service.dart` | `DeepLinkService` — abstract interface (`getInitialLink()` for a cold launch, `onLink` stream for links received while running) for incoming `com.stubapp.stub://...` deep links; currently only the Siri Shortcuts quick-log feature uses this |
| `app/lib/data/app_links_deep_link_service.dart` | `AppLinksDeepLinkService` — real `DeepLinkService` via the `app_links` package (`AppLinks().getInitialLink()`/`.uriLinkStream`). No automated test — needs a real platform channel, same story as `MlKitTextRecognitionService`/`LocalAuthDeviceAuthService`/`LocalNotificationsService` |
| `app/ios/Runner/LogExpenseIntent.swift` | `LogExpenseIntent` — an `AppIntent` (Apple's App Intents framework) exposing `amount` (required `Double`) and `merchant` (optional `String`) Shortcuts parameters; `perform()` builds `com.stubapp.stub://log-expense?amount=...&merchant=...` (merchant URL-encoded, its query item omitted entirely if nil/empty) and opens it via `UIApplication.shared.open(...)`; `openAppWhenRun = true` is deliberately kept (not migrated to iOS 26's `supportedModes`) since this target's deployment is iOS 16.0. `StubAppShortcuts: AppShortcutsProvider` makes it discoverable in the Shortcuts app/Spotlight. No automated test (needs a real device/Shortcuts app) — verify manually. `ios/Runner.xcodeproj/project.pbxproj` uses the old explicit-file-list format (not Xcode's newer synchronized groups), so this file's inclusion required 4 hand-added entries (`PBXBuildFile`/`PBXFileReference`/group child/Sources build phase) — verified structurally sound and that Xcode's own `xcodebuild -list` parses the project cleanly, but double-check `Runner.xcworkspace` opens cleanly in real Xcode before relying on it |
| `app/lib/screens/add_category_screen.dart` | `AddCategoryScreen` — new-category form (name, limit amount, an ICON picker — a `Wrap` of `categoryIconKeys`, each a private `_IconChoice` circle tinted in the currently-picked color — a COLOR picker (`_ColorChoice`, 6 swatches from `categoryColorCount`/`categoryColor`), a `DropdownButton` over `supportedCurrencies` — plus a `null`/"Default" entry — for the optional per-category currency override, `StubPeriodPicker` for the budget period); both pickers default to the first option (`'tag'`/index 0) if untouched; two sanity caps (not technical limits, easy to change) — name capped at `_maxNameLength` (40 chars, via `TextField.maxLength`) and limit amount (labeled just "Limit" — not "Monthly limit", since the period picker already covers weekly/yearly/custom too) capped at `_maxLimitAmount` (10,000,000,000, blocks save with a snackbar if exceeded) with `ThousandsSeparatorInputFormatter` (`util/thousands_input_formatter.dart`) live-inserting commas as you type ("1000000" → "1,000,000"; `_save()` strips them back out before `double.tryParse`); the CURRENCY label and its `DropdownButton` sit in one `Row` (label left, dropdown right — was stacked, moved per feedback) rather than the label-then-control-below layout the other sections still use; `onSave(name, limitAmount, periodType, periodStart, periodEnd, currencyCode, icon, colorIndex)` creates the category (with that override/icon/color) then the budget via `CategoryRepository`/`BudgetRepository`, opened from `BudgetsScreen`'s add-category tap (guarded by `RootShell._openAddCategory`'s 30-category cap — see that entry) |
| `app/lib/screens/budgets_screen.dart` | `BudgetsScreen` — no combined dollar hero (removed, see `category_detail_screen.dart`'s entry); per-category rows show the category's icon (`categoryIconData`, tinted via `categoryColorIndexFor(budget.categoryId, budget.colorIndex)`), an ellipsis-truncated name (`Expanded`/`maxLines: 1`), then `'${(budget.fraction*100).round()}%'` instead of a dollar amount — both the name and the percentage colored via `budgetStatusColor(budget.status, ...)`; the `StubProgressBar.status(progress, status: budget.status)` below it follows the same amber/red rule; each row has a delete `IconButton` (`onDeleteCategory`) and is itself tappable (`onCategoryTap` → `CategoryDetailScreen`, wrapped in `StubPressable` around the whole row — the inner delete button's own tap still resolves independently, verified by a dedicated test), there's an add-category tap (`onAddCategory`) that opens `AddCategoryScreen`, and the whole screen is wrapped in a `RefreshIndicator` (`onRefresh`, wired to `RootShell._handleRefresh`) for pull-to-refresh, matching `LedgerScreen`; an empty-state message ("No categories yet — add one below...") replaces the card's content when `budgets` is empty, above the existing "+ Add a category" button |
| `app/lib/screens/lock_screen.dart` | `LockScreen` — app unlock flow, real entry point before RootShell; single "Unlock" button calls `DeviceAuthService.authenticate()` (real biometric-or-passcode via `local_auth`, OS handles the fallback itself), shows a spinner while pending and an inline error on failure, calls `onUnlock` only on success |
| `app/lib/screens/backup_prompt_screen.dart` | `BackupPromptScreen` — one-time, skippable post-unlock prompt wrapping `StubAccountLinkPanel`; `main.dart`'s `_LockGate` shows it exactly once (tracked via `LocalPrefs.hasSeenBackupPrompt`/`setHasSeenBackupPrompt`) between unlock and `RootShell` |
| `app/lib/screens/profile_screen.dart` | `ProfileScreen` — the real Profile tab (Tab 2, replaces the old Ledger-content fallback): a tappable name row at the top ("Add your name" until set, else "First Last") opening a two-field `AlertDialog` that saves via `AccountLinkService.setName`, then anonymous/linked status line + `StubAccountLinkPanel` when anonymous (reused, not re-implemented), "Member since" (from `AccountLinkService.memberSince`), lifetime `Tracked`/`Categories` stats, and a Settings row that calls `onOpenSettings` — doesn't push routes itself, `RootShell` owns navigation like every other screen here |
| `app/lib/screens/settings_screen.dart` | `SettingsScreen` — theme picker (Light/Dark/System via `StubChip`, writes through `LocalPrefs.setThemeMode` and the live `themeModeNotifier`), a currency picker (`DropdownButton` over `supportedCurrencies`, writes through `LocalPrefs.setCurrencyCode` and the live `currencyNotifier` — the app's global display-currency default), a SECURITY section with a "Require Face ID / Passcode" toggle (only rendered when `lockSupported` is true — nothing to require on a device with no biometric/passcode enrolled at all — writes through `LocalPrefs.setLockEnabled` and the live `lockEnabledNotifier`, same pattern as theme/currency), two real notification toggles (`SwitchListTile.adaptive`) — both call `notificationService.requestPermission()` when turned on (showing a snackbar if denied); "Budget limit warnings"' actual firing logic lives in `RootShell`, "Weekly summary"'s turns the real background task on/off via `onWeeklySummaryToggled(enabled)` (a callback, not a direct `workmanager` call, since `workmanager` has no fake and can't run inside a widget test — `RootShell` wires it to the real `scheduleWeeklySummary`/`cancelWeeklySummary`), `Export data` (`StubButton` → `onExportData`, a plain `VoidCallback` — `RootShell` wires it to open `ExportDataScreen` rather than exporting directly), `Delete all data` (confirmation `AlertDialog` first, then `onDeleteAllData`), and a disabled "Delete account — Coming soon" row |
| `app/lib/screens/export_data_screen.dart` | `ExportDataScreen` — lets the user narrow a CSV export to one MONTH (`DropdownButton` over `ExportMonth`s derived from the actual transaction dates present, defaulting to the most recent one, plus an "All time" entry) and a subset of CATEGORIES (`StubChip` multi-select, `Set<String>`, defaulting to all checked) instead of always exporting every transaction ever with no way to scope it down; `onExport(month, categoryNames)` fires only once at least one category is selected (`Export CSV`'s `StubButton` is disabled otherwise); `ExportMonth` (year+month value with `==`/`hashCode` so it works as a `DropdownButton`/`Set` value) is a small public class other code can reuse. Opened from `RootShell._openExportData`, which fetches the full (already-paginated-through) transaction list first so the month picker reflects real data |
| `app/test/widget_test.dart` | App-level smoke test — boots locked, unlocks into the real ledger, `pumpAndSettle`s past the post-unlock async data load |
| `app/test/models_test.dart` | Tests for `Transaction`/`CategorySpend`/`BudgetLimit` |
| `app/test/data/fakes_test.dart` | Tests for `FakeCategoryRepository`/`FakeTransactionRepository`/`FakeBudgetRepository` create/list/update/delete in-memory behavior |
| `app/test/theme/category_colors_test.dart` | Tests for `categoryColor`'s deterministic cycling and light/dark divergence |
| `app/test/widgets/*_test.dart` | One test file per reusable widget (`stub_bottom_nav`, `stub_card`, `stub_chip`, `stub_field_row`, `stub_hero_amount`, `stub_icon`, `stub_period_picker`, `stub_pressable`, `stub_progress_bar`, `stub_progress_ring`, `stub_transaction_tile`) — same basename as the widget under `lib/widgets/` |
| `app/test/screens/*_test.dart` | One test file per screen (`add_category_screen`, `backup_prompt_screen`, `budgets_screen`, `edit_entry_screen`, `ledger_screen`, `lock_screen`, `manual_entry_screen`, `profile_screen`, `root_shell`, `scan_screen`, `settings_screen`) — same basename as the screen under `lib/screens/` |
| `app/test/util/currency_test.dart` | Tests for `formatCurrency` (including the negative-amount case, `CurrencyConfig.code`, and an explicit `currencyCode` override), and for `supportedCurrencies` (non-empty, no duplicate codes, includes USD/EUR) |
| `app/test/util/csv_export_test.dart` | Tests for `buildTransactionsCsv`'s field quoting/escaping and row shape (the pure half of `csv_export.dart`; `exportTransactionsCsv`'s real file-write/share-sheet call is not unit-tested) |
| `app/test/util/receipt_parser_test.dart` | Tests for `parseReceiptLines`'s amount/date/merchant extraction, `_reconstructReadingOrder`'s row-clustering, and `redactLongDigitRuns`'s digit-run masking; `MlKitTextRecognitionService` itself has no automated test — ML Kit needs a real device/platform channel, so it's exercised only manually (see Open items) |
| `app/tool/generate_icon_test.dart` | Renders `StubLogo` to `assets/icon/icon.png` for `flutter_launcher_icons`; re-run if the mark changes |
| `app/tool/generate_launch_image_test.dart` | Renders the same mark (transparent background, platform launch-screen configs supply the actual bg color) at a 120x120 logical size, 1x/2x/3x straight into `ios/Runner/Assets.xcassets/LaunchImage.imageset/` and 1x into `android/.../drawable-nodpi/launch_image.png`, for the native launch screen (`LaunchScreen.storyboard` / `launch_background.xml`) — an Airbnb-style centered logo on a plain background shown instantly on app open, before the Flutter engine/lock screen. Background now follows the app's light/dark theme rather than always being light (per feedback after real-device testing): iOS via a `LaunchBackground` Color Set (`Assets.xcassets/LaunchBackground.colorset`, Any=`bgLight`/Dark=`bgDark`) the storyboard references by name instead of an inline RGB value; Android via `drawable-night(-v21)/launch_background.xml` variants alongside the existing light ones. Re-run this generator if the mark or its size changes; keep `LaunchScreen.storyboard`'s declared `LaunchImage` width/height in sync with `_logicalSize` by hand |
| `app/supabase/config.toml` | Supabase CLI project config (linked to `jlygdlftvvgmekjcawgr`); `[auth]` has `enable_anonymous_sign_ins = true`, pushed to and confirmed working against the real remote project |
| `app/supabase/migrations/20260826222620_real_data_foundation.sql` | The real schema: `categories`/`budgets`/`transactions` tables (all with RLS, `select`/`insert`/`update`/`delete` "own rows only" policies keyed on `auth.uid()`), plus the `budget_progress` view (`security_invoker`) that joins each budget to its category name and sums transactions within the current period (weekly/monthly/yearly computed from `now()`, custom uses `period_start`/`period_end`) |
| `app/supabase/migrations/20260908144808_category_currency.sql` | Adds nullable `categories.currency_code` (checked at the DB level against the same code list as `lib/util/currency.dart`'s `supportedCurrencies` — keep both in sync by hand if either changes; **not yet pushed to the remote project** — blocked on `supabase login` re-auth, see Open items) and updates `budget_progress` to also select it |
| `app/supabase/migrations/20260908183000_category_icon_color.sql` | Adds `categories.icon` (`not null default 'tag'`, checked against the same key list as `lib/theme/category_icons.dart`'s `categoryIconKeys` — keep both in sync by hand) and nullable `categories.color_index` (checked `0-5`, matching `category_colors.dart`'s 6-slot palette); updates `budget_progress` to also select both. **Not yet pushed to the remote project** — same `supabase login` re-auth blocker as the currency migration above, see Open items |
| `app/l10n.yaml` | `flutter gen-l10n` config (`arb-dir: lib/l10n`, `template-arb-file: app_en.arb`) — scaffolding only for the still-unstarted English/Spanish localization; no ARB files exist yet |
| `app/lib/config/backend_config.dart` | `BackendMode` (`supabase`/`customServer`) + `BackendConfig.mode`/`baseUrl` — the single switch point between the two coexisting backends; `main.dart` branches on `mode` to construct either the `Supabase*` or the `Http*` set of repositories/services. Currently defaults to `customServer`. `baseUrl` is `http://localhost:3000` — change it to the Mac's LAN IP (`ipconfig getifaddr en0`) when testing from a physical phone, which can't reach the Mac's `localhost` |
| `server/` (repo root) | The self-hosted Node 20 + TypeScript + Postgres 16 backend — a **sibling alternative to Supabase, not a replacement**: every `Supabase*Repository`/`SupabaseAccountLinkService` stays in the tree untouched for a future switch back (see `docs/superpowers/specs/2026-09-09-custom-backend-migration-design.md`). Express 5 + raw parameterized `pg` SQL (no ORM), JWT auth (`jsonwebtoken`, 365d tokens), and the same Postgres RLS defense-in-depth Supabase gave us — `src/db.ts`'s `withUserContext(userId, fn)` opens a transaction and `set_config('app.current_user_id', ...)`s it before the query, which every table policy keys on. `src/routes/{auth,account,categories,transactions,budgets}.ts` is one thin router per resource; `migrations/1757000000000_init.js` (run via `node-pg-migrate up`) ports all three Supabase migrations plus the `budget_progress` `security_invoker` view near-verbatim, so `GET /budgets` returns the same shape the app already consumes. Every error is `{ error: { code, message } }` (`app.ts`'s catch-all is `internal_error`/500 with no stack or SQL leaked). Both `POST /transactions` and `POST /budgets` insert via `insert ... select from categories where id = $2` rather than `values` — an application-level ownership check, because Postgres's FK constraint runs with elevated privileges and **bypasses RLS**, so without it user B could reference user A's `categoryId` and permanently block A from deleting (`on delete restrict`) or budgeting (`unique (category_id)`) their own category. Run it with `cd server && docker compose up -d --build` |
| `server/test/*.test.ts` | Jest + `supertest` integration tests against a **real** Postgres (the `server-postgres-1` container) — genuinely new coverage this project never had for Supabase (see the Testing approach note below). One file per resource plus `db.test.ts` (the RLS helper itself) and `error_handling.test.ts` (the shared 500 handler's body shape). `jest.config.js` sets `maxWorkers: 1` deliberately: every file's `beforeEach` truncates the shared tables, so parallel files would race each other's cleanup |
| `server/seed/seed.ts` | School-assignment Faker seeder (not app logic) — bulk-inserts ~3,000 fake users, ~18,000 categories/budgets, and 1,200,000+ transactions directly into Postgres (bypassing RLS via the `postgres` superuser role, `DATABASE_URL`), then exports a signed JWT + category IDs per user to `seed/output/users.json` (gitignored) for the k6 load test to consume. Refuses to run unless `DATABASE_URL`'s host looks local, since it unconditionally `TRUNCATE`s every app table first. Run via `cd server && npm run seed` |
| `server/loadtest/scenario.js` | k6 load test (school-assignment requirement: a target profile of ~500,000 requests over 7 minutes, peaking at ~145,000 requests in one minute) against the real running API, using `seed/output/users.json`'s tokens; weighted 85/15 toward reads (`GET /transactions`/`/budgets`/`/categories`/`/account`) over writes (`POST /transactions`). `SMOKE=1 k6 run scenario.js` runs a 15s/5rps sanity check instead of the full profile — this passes reliably (100% checks succeeded across every real run in this environment). **The full profile has not been achieved against this local Docker stack** (see the new CLAUDE.md paragraph below, after "Backend/database: two backends, one switch," for the full finding): `preAllocatedVUs`/`maxVUs` were raised from the original `300`/`1000` to `2000`/`8000` after a real 7-minute run at the lower values completed only 110,766 of the target ~493,020 requests (0% failed, but 383,273 dropped — k6 ran out of VUs to sustain the arrival rate given this API's real per-request latency under load). Raising the VU ceiling did **not** fix this: a second real 7-minute run at `2000`/`8000` completed 128,580 requests but with 93.28% *failed* (119,951 failures — timeouts and connection resets), and the API container was confirmed to have crashed and been auto-restarted mid-run by Docker's `restart: unless-stopped` policy. Run the real thing via `k6 run --out experimental-prometheus-rw scenario.js` with `docker compose up -d` (postgres/api/prometheus/grafana) already running; view results live at `http://localhost:3001` (Grafana, anonymous viewer access, dashboard auto-provisioned from `server/loadtest/grafana/provisioning/`) |
| `app/lib/data/api_client.dart` | `ApiClient` + `ApiException` (carries the server's `error.code`, so callers branch the same way they already do on `PostgrestException.code`) — the shared HTTP layer under every `Http*` class. Owns the session lifecycle: `_ensureToken()` reads the stored JWT or `POST`s `/auth/anonymous`, **memoizing the in-flight sign-in in `_tokenFuture`** so two callers racing at cold start (`HttpAccountLinkService`'s constructor vs. `RootShell._load()`) share one sign-in instead of creating two `users` rows and silently orphaning one (a real, confirmed bug, caught by the whole-branch review). `_tokenFuture` is cleared in a `finally` — on failure too, so a failed sign-in can't wedge every later caller onto a dead future. `_send` retries the entire request **exactly once** on a `401` (delete the token, re-run `_ensureToken`, re-issue), recovering from an expired/orphaned JWT that previously left the app permanently stuck until app data was manually cleared; a second 401 falls through to the throw, so it can't loop |
| `app/lib/data/local_auth_token_store.dart` | `LocalAuthTokenStore` — `SharedPreferences`-backed `readToken`/`writeToken`/`deleteToken` for the custom backend's JWT, the role Supabase's own session persistence plays today. `deleteToken` exists for `ApiClient`'s 401 recovery above (see Open items — a JWT is more sensitive than `LocalPrefs`' UI-only values, so `flutter_secure_storage` is worth revisiting) |
| `app/lib/data/http_category_repository.dart`, `http_transaction_repository.dart`, `http_budget_repository.dart`, `http_account_link_service.dart` | The `Http*` implementations of the same four interfaces the `Supabase*` classes implement — thin mappers over `ApiClient`, no logic of their own beyond row shaping. `HttpAccountLinkService` differs from its Supabase sibling in one way that matters: its getters are filled in by an async `/account` fetch kicked off in its constructor, not from an already-cached session, so it emits on `linkStatusChanges` when that lands and `ProfileScreen` subscribes to rebuild (closing what was a long-standing "no subscriber" Open item) |
| `ocr-spike/` (repo root) | The OCR accuracy spike — Swift scripts, sample images, raw results. Findings are already summarized in this file's "OCR/parsing spike" section below; only open the raw folder if you need something beyond that summary. |

---

## What Stub is

A screenshot-first budgeting app: instead of connecting a bank account,
users screenshot receipts, payment-app confirmations (Venmo/Zelle-style),
and bank-app screenshots, and the app parses them into transactions. The
core pitch is **no bank login, ever** — parsing happens on-device where
possible, with cloud vision fallback only for low-confidence reads (redact
account numbers before any such request). Monetization is freemium
subscription (a capped free tier, paid tier unlocks unlimited
scans/sources) — not ads, not a one-time purchase, since neither fits the
trust story or the cost structure.

## Tech stack: Flutter

Decided: **Flutter** (Dart), targeting iOS + Android from one codebase.
Chosen over React Native for rendering fidelity — Flutter draws its own UI
(Skia-based, not native platform widgets), which matters for this app's very
custom design system (specific font pairing, gradient-clipped numerals, the
scan/develop animation) rendering identically on both platforms without
per-platform polish work. Chosen over native SwiftUI-only because
multi-platform was an explicit requirement.

**On-device OCR**: use `google_mlkit_text_recognition` (Google ML Kit),
Flutter's cross-platform equivalent to the Apple Vision framework used in
the OCR spike — free, on-device, works on iOS and Android. The spike's
*architecture* conclusion (on-device-first, cloud-fallback for itemized
receipts, position-based line reconstruction) carries over; the exact
accuracy numbers do not automatically transfer since it's a different OCR
engine — worth a quick re-validation against the same sample images once
ML Kit is wired up, rather than assuming Vision's numbers hold.

**Project location**: `app/` (Flutter project root, package name `stub`).
Flutter SDK installed at `~/development/flutter`, on PATH via `~/.zshrc`.

**Commands** (run from `app/`):
- `flutter analyze` — static analysis, run before considering any change done
- `flutter test` — widget/unit tests
- `flutter run` — run on a connected device/simulator
- `flutter pub add <package>` — add a dependency; **never hand-edit a
  version number into pubspec.yaml** — let this resolve the real current
  version instead of guessing

**Folder structure** (mirrors CLAUDE.md's reuse-first rule):
- `lib/theme/` — `colors.dart` (every hex value from DESIGN.md §2, nothing
  invented here), `text.dart` (the 3-font system from DESIGN.md §1),
  `app_theme.dart` (wires both into light/dark ThemeData)
- `lib/widgets/` — reusable components (`StubButton` first; add to this
  folder + the Component inventory table below as new ones are built)
- `lib/screens/` — one file per screen, ported from `mockups.html` one at a
  time

**Status**: theme + all reusable components (`StubButton`, `StubLogo`, `StubIcon`, `StubCard`, `StubChip`, `StubFieldRow`, `StubProgressRing`, `StubProgressBar`, `StubTransactionTile`, `StubBottomNav`/`StubNavItem`, `StubHeroAmount`, `StubPressable`, `StubPeriodPicker`, `StubProviderRow`, `StubAccountLinkPanel`) wired and verified (`flutter analyze` clean, 211 tests passing; plus 20 server-side Jest integration tests, see `server/test/`). All 7 real screens (Ledger, Scan, Edit Entry, Manual Entry, Budgets, Lock, Add Category) ported/added and wired via `RootShell` navigation shell, plus the one-time `BackupPromptScreen` and the Profile & Settings pair (`ProfileScreen`, `SettingsScreen`). `main.dart` now gates on `LockScreen`, which requires real device biometric/passcode auth via `DeviceAuthService`, then the one-time backup prompt, before showing the real app — and re-locks immediately whenever the app backgrounds.

The app now reads and writes **real data** through Supabase, not sample data: `main.dart` calls `Supabase.initialize()` then `_ensureSession()` (silently `signInAnonymously()`s if there's no existing session — anonymous auth is enabled and verified working against the real remote project, see the Supabase section below), then constructs the three real `Supabase*Repository` implementations plus `SupabaseAccountLinkService` and `LocalPrefs`, and threads them down through `StubApp` → `_LockGate` → `RootShell`. `RootShell` loads categories/transactions/budgets on init, reloads after every write, and wires Ledger's manual-entry FAB, Edit Entry's save/delete, and a new Add Category screen (name + limit + period, via `StubPeriodPicker`) all the way through to Postgres. Tab 2 "Profile" now shows the real `ProfileScreen` (it no longer falls back to Ledger content): anonymous/linked status, `StubAccountLinkPanel` reused for the Email link flow, lifetime stats, and a `Settings` row that opens `SettingsScreen` (live theme switching persisted via `LocalPrefs` + a `ValueNotifier<ThemeMode>` read at startup in `main.dart`, two notification toggles that are UI-only so far, CSV export via `share_plus`, and delete-all-data behind a confirmation dialog, both wired through `RootShell`). Linking a persistent identity (Phase 2) is implemented for Email: `_LockGate` shows `BackupPromptScreen` once per device (tracked via `LocalPrefs`) after first unlock, offering Email (functional, via `AccountLinkService.linkEmail`), Apple/Google/Phone (visibly disabled, "Coming soon"); the same panel and the same Email flow are reachable again later from `ProfileScreen` for anyone who skipped the prompt. `ScanScreen` now performs a real capture (camera or photo library via `image_picker`) and a real on-device OCR pass (`TextRecognitionService` — `MlKitTextRecognitionService` in production, backed by Google ML Kit) followed by position-based parsing (`parseReceiptLines`, see `receipt_parser.dart`'s entry above); its result flows through `RootShell._handleScanned`/`_openScanCreateFlow` into `EditEntryScreen(isCreating: true, ...)`, pre-filled with the parsed merchant/amount for mandatory human review, and on save creates a real transaction via `TransactionRepository.create` — no longer a hardcoded no-op stub.

Real app icon generated and installed for both iOS and Android via `tool/generate_icon_test.dart` (renders `StubLogo`'s exact geometry to `assets/icon/icon.png`) + `flutter_launcher_icons`. iOS build confirmed working end to end (`flutter build ios --debug --no-codesign` succeeds).

**Testing approach**: all 211 Flutter tests are pure-Dart widget/unit tests run via `flutter test` against the in-memory fakes in `lib/data/fakes.dart` (or, for models/utils, no backend at all) — there is no integration test suite that hits the real Supabase project. The `Supabase*Repository`/`SupabaseAccountLinkService` implementations (`lib/data/supabase_*.dart`) are exercised only by manual/CLI verification during implementation (recorded in the task reports under `.superpowers/sdd/2026-08-26-real-data-foundation/`, `.superpowers/sdd/2026-08-27-account-linking-phase2/`, `.superpowers/sdd/2026-08-27-profile-and-settings/`, and `.superpowers/sdd/2026-09-06-receipt-scanner/`), not by an automated test run against the live database. `csv_export.dart`'s real half (`exportTransactionsCsv`'s temp-file write + OS share sheet) is likewise unverified by an automated test — only its pure CSV-building logic (`buildTransactionsCsv`) is unit-tested; see Open items. `MlKitTextRecognitionService` is the same story: `receipt_parser.dart`'s pure parsing logic is unit-tested, but the real ML Kit call has no automated test — it needs a physical device (see Open items and the iOS setup notes below). `LocalAuthDeviceAuthService` is the same story again: `LockScreen`/`_LockGateState`'s logic is unit/widget-tested against `FakeDeviceAuthService`, but the real `local_auth` call has no automated test — see Open items. `LocalNotificationsService` is the same story once more: the threshold-crossing logic and `RootShell`'s wiring are fully tested against `FakeNotificationService`, but the real `flutter_local_notifications` call has no automated test — see Open items. One exception: `LocalPrefs` (a concrete class, not an interface) has its unlock-time failure path exercised for real by installing a throwing `SharedPreferencesStorePlatform` in `app/test/widget_test.dart`, rather than by a hand-rolled fake of `LocalPrefs` itself.

## Backend/database: two backends, one switch

The app can run against **either** backend, and both stay in the tree:
Supabase (documented in the section below, still fully working) and a
self-hosted Node/TypeScript + Postgres server in `server/` (see its file-map
rows above and
`docs/superpowers/specs/2026-09-09-custom-backend-migration-design.md`).
Nothing is duplicated at the call site — the `Supabase*` and `Http*` classes
are sibling implementations of the same four interfaces
(`CategoryRepository`, `TransactionRepository`, `BudgetRepository`,
`AccountLinkService`), and `main.dart` picks a set based on
`app/lib/config/backend_config.dart`'s `BackendConfig.mode`. That one
constant **currently defaults to `BackendMode.customServer`**; flipping it
back to `BackendMode.supabase` fully reverts the app, no other change
needed. `RootShell` is the only screen that had to learn about both: it
catches `PostgrestException` and `ApiException` side by side, with
`_friendlyMessage`/`_friendlyMessageForApiException` mapping each backend's
error codes to the same user-facing sentences (so e.g. a duplicate category
name reads identically whether it arrived as Postgres `23505` or as the
server's `duplicate_name`/409).

To run the custom backend locally: `cd server && docker compose up -d
--build` — that brings up `postgres` (port 5432, named volume) and `api`
(port 3000, runs `npm run migrate up` then the server on boot). Confirm with
`curl http://localhost:3000/health` → `{"status":"ok"}`. Tests:
`cd server && npm test` (needs the `postgres` container up; runs against it
for real, sequentially — see `jest.config.js`'s `maxWorkers: 1`).

**School-assignment load-testing tooling** (`server/seed/`, `server/loadtest/`) is separate from both backends above — it's grading/demo tooling that bulk-seeds Postgres directly and load-tests the custom `server/` API with k6, visualized live via Prometheus + Grafana (added to `server/docker-compose.yml`). It has no automated test coverage (not app logic) and is meant to be run against a disposable local database — see those two file-map rows above for how to run it. **Real-run finding (2026-09-16): the full ~500,000-request/7-minute profile has not been achieved against this local Docker stack.** Three full 7-minute runs were executed against a freshly seeded 1.2M-transaction database, diagnosing two real, confirmed problems in `server/src/db.ts`, one of which is now fixed here (a narrowly-scoped, user-approved exception to this task's normal "no `server/src/**` changes" rule — resource tuning only, no route/business-logic changes):
1. *(original `scenario.js`, `preAllocatedVUs: 300`/`maxVUs: 1000`, unfixed `db.ts`)* — completed only 110,766 of the ~493,020 target requests with 0% failures (383,273 dropped — k6's own VU pool couldn't sustain the target arrival rate given this API's real per-request latency under load, avg 3.12s/p95 6.49s). Root cause: `pg.Pool` defaulted to `max: 10` concurrent DB connections, so most requests queued for a pool slot rather than running.
2. *(VUs raised to `2000`/`8000` to remove that ceiling, unfixed `db.ts`)* — made things categorically worse: 128,580 requests completed but 93.28% *failed* (timeouts/connection resets), and `docker compose ps` confirmed the `api` container had crashed and been auto-restarted mid-run. Cause: pooled `pg.Client` connections have no `.on('error', ...)` handler, so Node's default EventEmitter behavior turns a dropped/reset DB connection (expected under this much connection churn against only 10 pool slots) into an uncaught exception that kills the whole process (confirmed via `docker compose logs api`: `Error: Connection terminated unexpectedly` immediately followed by a full process exit and restart).
3. *(fix applied: `db.ts`'s `pg.Pool` now sets `max: 80`; VUs dialed back down to a moderate `preAllocatedVUs: 500`/`maxVUs: 2000` safety margin)* — this genuinely fixed problem #2: no crash, no restart, and the failure rate dropped from 93.28% to 20.48% (14,807 of 72,295 requests). But the total is still far short of target (72,295 requests; peak minute sampled via Prometheus at ~11,500, not ~145,000) and `http_req_duration` was still high (avg 10.53s, p95 33.6s) with 421,744 further dropped iterations. Manual `ab`/`curl` concurrency probes (done during diagnosis, not part of the k6 runs) isolated the remaining ceiling to the single Node process itself, not Postgres or the connection pool: sustained throughput plateaued at roughly 350-575 req/s regardless of concurrency level (10 through 300) or `pg.Pool.max` size, while individual queries under RLS measured only ~10ms — i.e. this is a CPU-bound single-event-loop ceiling, not a database wait. `docker top` during a burst confirmed only one `node dist/index.js` process exists — there is no clustering/multi-worker setup in `server/src/index.ts` (a same-session experimental version that forked one worker per CPU core was built, measured, then reverted — see the plan's task ledger — since it fell outside the pool-size-only exception ultimately approved for this task).
4. *(Docker Desktop's memory allocation raised from ~3.8GB to ~5.8GB, stack rebuilt fresh, same `db.ts`/`scenario.js` settings as run 3, one final confirmation run)* — essentially unchanged from run 3: 73,220 requests (18.40% failed), peak minute sampled at ~13,500, no crash. This confirms the earlier finding: the remaining ceiling is CPU-bound (a single Node event loop), not memory-bound, so the extra RAM made no material difference.

The seeder and k6 script themselves both work correctly end to end (100% checks pass on `SMOKE=1` every time, and every non-timed-out request across all four full runs got a correct response) — the remaining shortfall is a real backend capacity/architecture gap, not a bug in the load-testing tooling, and not something more Docker memory or connection-pool tuning can fix. **Final achieved numbers on this machine: ~73,000 total requests over 7 minutes (vs. the ~493,020 target) with an ~13,500 peak minute (vs. the ~145,000 target), at an 18.4% request-failure rate under the full ramp profile** (both the `SMOKE=1` sanity check and the ramp's early/low-concurrency stages pass at 100% — the failures are concentrated in the profile's higher-rate stages once the single Node process's real throughput ceiling is exceeded). Treat the ~145,000-peak-minute/~493,020-total figures in the file-map rows above as this tooling's *target design profile*, not a number this specific local environment has been shown to sustain. A follow-up task to cluster `server/src/index.ts` across the host's CPU cores (with `db.ts`'s pool sized per-worker accordingly) is recommended before that target is achievable here — this was explicitly out of scope for this task (only a `db.ts` connection-pool-size exception was approved, not an `index.ts` architecture change). To be clear about what this finding does and doesn't mean: the seeder and k6 script are both built correctly and would produce the full ~493,020-request/~145,000-peak-minute result on infrastructure with more real throughput capacity — a non-laptop host, a clustered/horizontally-scaled API, or a cloud test environment. The ceiling documented here is specific to this local single-process API running on this laptop's Docker Desktop, not a defect in the load-testing tooling's design.

## Backend/database: Supabase

Decided: **Supabase** (Postgres + Auth + Storage) for the backend. When
working on anything Supabase-related in this project (schema, RLS, auth,
storage, edge functions), load the `supabase` skill first — it has
project-specific gotchas (RLS policy patterns, view security, migration
workflow) that matter for getting this right the first time, not just
"connect to a database."

**Status**: project created (`jlygdlftvvgmekjcawgr`,
https://jlygdlftvvgmekjcawgr.supabase.co). Flutter app wired up and
verified — `supabase_flutter` added, `Supabase.initialize()` runs in
`main.dart` using `lib/config/supabase_config.dart` (publishable key only,
client-safe by design; never put the secret/service_role key here).
`flutter analyze` clean, tests passing.

CLI authenticated (personal access token, correct account) and linked —
`supabase/.temp/project-ref` confirms `jlygdlftvvgmekjcawgr`. Run CLI
commands from `app/` (where `supabase init` created the `supabase/`
folder).

**Schema** (migration: `app/supabase/migrations/20260826222620_real_data_foundation.sql`,
pushed to and live on the linked remote project):
- `categories` — `id`, `user_id` (FK `auth.users`, `on delete cascade`), `name`,
  `created_at`; unique `(user_id, name)`.
- `budgets` — `id`, `user_id`, `category_id` (FK `categories`, `on delete cascade`,
  unique — one budget per category), `limit_amount`, `period_type`
  (`weekly`/`monthly`/`yearly`/`custom`), `period_start`, `period_end`
  (required when `period_type = 'custom'`), `created_at`.
- `transactions` — `id`, `user_id`, `category_id` (FK `categories`, **`on delete
  restrict`** — a category with transactions can't be deleted; `RootShell`
  catches this as Postgres error code `23503` and shows a snackbar instead of
  silently failing), `merchant`, `amount` (`> 0` only), `source`
  (`receipt`/`payment_app`/`bank_screenshot`/`manual`), `image_path` (nullable,
  unused so far — no upload path wired to it yet), `occurred_at`, `created_at`.
- `budget_progress` — a `security_invoker` view joining each budget to its
  category name and summing same-period transactions (period boundaries
  computed from `now()` for weekly/monthly/yearly, from `period_start`/
  `period_end` for custom); this is what `SupabaseBudgetRepository.list()`
  actually reads from, not the `budgets` table directly.
- RLS is enabled on all three tables with `select`/`insert`/`update`/`delete`
  policies scoped to `user_id = (select auth.uid())` — every row is
  own-rows-only, verified against the real (not just local) project.
- No user-profile table yet — nothing beyond the anonymous `auth.users` row
  itself.

**Auth**: anonymous sign-in (`enable_anonymous_sign_ins`) is enabled on the
**remote** project (this was initially `false` there and had to be flipped
and pushed — see Task 5 in this plan's ledger) and confirmed working via a
direct REST call and via the app's own `_ensureSession()` in `main.dart`.
Phase 2 (linking a persistent identity onto that anonymous session) is now
implemented for **Email only** — `SupabaseAccountLinkService.linkEmail`
calls `auth.updateUser` with `emailRedirectTo:
'com.stubapp.stub://login-callback'`; `app/supabase/config.toml`'s
`auth.additional_redirect_urls` includes that same
`com.stubapp.stub://login-callback` scheme so Supabase accepts it as a
valid redirect target for the confirmation link. Apple/Google/Phone are
visibly present in the UI (`StubAccountLinkPanel`) but disabled pending
external provider accounts. An anonymous user who never links anything
still loses their data if the device/app data is lost — that gap is now
closed only for users who complete the Email link.

**iOS setup notes**:
- iOS deployment target bumped from Flutter's default 15.0 to **16.0** in
  both `ios/Podfile` and `ios/Runner.xcodeproj/project.pbxproj` — required
  by `google_mlkit_commons`'s native dependencies. If Xcode ever shows
  "Module 'google_mlkit_commons' not found," it means Pods weren't
  (re)installed after a pubspec change — run `flutter clean && flutter pub
  get && cd ios && pod install`.
- **ML Kit does not support the iOS Simulator on Apple Silicon** (no arm64
  simulator slice in its pods). This isn't worth working around — the scan
  feature needs a real camera anyway, so test on the connected physical
  iPhone, not the simulator.
- The Xcode project's "Profile" build configuration still points at
  `Release.xcconfig` instead of a profile-specific one (a pre-existing gap
  in Flutter's default template, not something introduced here) — harmless
  for normal Debug/Release work, only matters if someone later needs
  `flutter run --profile` for performance profiling.

## The mockup artifact

`mockups.html` is published as a Claude Artifact. Republishing the *same
file path* in a session that has access to it keeps the same URL —
publishing without that continuity (e.g. a fresh session that doesn't know
the URL) creates a separate, disconnected artifact instead. If a session
needs to update the mockup and doesn't have the URL in context, use the
Artifact tool's list/read actions to find the existing one rather than
publishing fresh.

## App size (measured, not estimated)

`flutter build ios --release --no-codesign` produces a **66MB** on-disk
`Runner.app` (49MB main binary/Flutter engine, 16MB Frameworks — mostly
Google ML Kit's native libraries, 772KB is the actual OCR model bundle
itself). Adding `supabase_flutter` moved this only 1MB (65MB → 66MB) — its
client SDK is lightweight; ML Kit's OCR is what dominates the size, not the
backend. This is an unsigned build, not a true App Store archive, so the
real App Store download size will likely be somewhat smaller (compression +
per-device app thinning). Re-measure with a signed release archive once
that's set up, rather than quoting this number as final.

**Beware `--debug` vs `--release` when re-measuring**: a debug build of
this same app measures ~174MB — debug builds bundle extra
hot-reload/JIT machinery that never ships to real users. Always measure
`--release` for a number that means anything about real app size.

## Open items

- **The weekly summary silently no-ops under `BackendMode.customServer`.**
  `weekly_summary_scheduler.dart`'s `weeklySummaryCallbackDispatcher` runs in
  a fresh background isolate with none of the app's state and re-initializes
  **Supabase** from scratch to query the last 7 days — there's no injected
  `ApiClient` out there, and no date-filtered server endpoint to call even if
  there were. Real support needs one or the other; deliberately not built in
  this pass. The toggle in `SettingsScreen` still registers/cancels the
  `workmanager` task as before, it just won't produce a notification on the
  custom backend.
- **The custom backend's secrets are dev-only placeholders.** The `app_user`
  Postgres role password (`app_user_password`, set in
  `migrations/1757000000000_init.js` and repeated in `server/docker-compose.yml`
  + `server/.env.example`) and `JWT_SECRET` (`dev-secret-change-me`) are both
  hardcoded. Fine for `localhost` Docker Compose, which is all this is scoped
  to today — but they must be parameterized and rotated before this reaches
  any non-local host. Same note as the still-undecided production deployment
  target (always-on host, TLS, domain).
- **`server`'s `users` table has no RLS policy.** Every other table
  (`categories`/`budgets`/`transactions`) has one, keyed on
  `app.current_user_id`, as defense-in-depth behind the application code.
  `users` doesn't, because the only two things that touch it need to work
  outside that model: `POST /auth/anonymous` runs pre-auth (there's no user
  id yet), and `/account`'s reads/writes are already scoped to the JWT's own
  `req.userId`. So authorization there is application-code-only — the one
  place in the schema without the second layer.
- **Custom-backend edge-case gaps, all defense-in-depth rather than open
  holes** (the primary mechanism — JWT-derived ownership plus RLS — already
  holds in each case): `GET /transactions`' `?offset=`/`?limit=` query params
  aren't validated or clamped; there's no test proving a forged or expired
  JWT is rejected (`requireAuth` does verify signature and expiry); there's
  no test proving a cross-user `PATCH`/`DELETE` on a transaction is a no-op
  (RLS makes it one); and `server/` has no `.dockerignore`, so the image
  build copies more than it needs before `npm install` overwrites
  `node_modules`.
- **`LocalAuthTokenStore` keeps the JWT in `SharedPreferences`, not secure
  storage.** Chosen at implementation time for symmetry with `LocalPrefs`,
  but a bearer token is materially more sensitive than the UI-only prefs that
  class was built for — `flutter_secure_storage` is worth revisiting before
  shipping.
- **Nothing about the custom backend has been verified from a physical
  device.** The server has real integration test coverage against a real
  Postgres, and `flutter analyze`/`flutter test` are clean, but no phone has
  actually talked to the Dockerized server over LAN (which also means
  `BackendConfig.baseUrl` has never been exercised as anything but
  `localhost`) — same story as every other "real backend" item in this list.
- **`categories.currency_code`/`icon`/`color_index` migrations not yet
  pushed.** `supabase db push`/`supabase projects list` are currently
  returning `401 Unauthorized` — the CLI's auth token needs refreshing
  (`supabase login`) before `20260908144808_category_currency.sql` or
  `20260908183000_category_icon_color.sql` can reach the real remote
  project. Until then, `AddCategoryScreen`'s currency/icon/color pickers
  write values that `SupabaseCategoryRepository.create` will try to insert
  into columns that don't exist remotely yet.
- **Siri Shortcuts quick-log ("Log Expense to Stub") is iOS-only and not
  yet verified on a real device.** A Shortcuts automation can call
  `LogExpenseIntent` to deep-link into a pre-filled `ManualEntryScreen`
  (never a silent save — same "human review required" rule as the OCR
  scan flow). The Dart side (parsing, `RootShell`/`StubApp` wiring, the
  real `AppLinksDeepLinkService`) is fully unit/widget-tested. The native
  side (`LogExpenseIntent.swift`) has no automated test — it type-checks
  and the Xcode project parses cleanly via `xcodebuild -list`, but a full
  target build (needs `pod install`), Xcode's file navigator display,
  Shortcuts-app discovery, the Siri phrase, and the true end-to-end "run a
  Shortcut → Stub opens pre-filled" flow have never been tested on a
  physical device. No Android equivalent — Shortcuts/App Intents is an
  iOS-only concept.
- **Language switching (English/Spanish UI) is scaffolded but not
  implemented.** `flutter_localizations`/`intl` are added to
  `pubspec.yaml`, `l10n.yaml` is configured, and `LocalPrefs.localeCode`/
  `setLocaleCode` exist — but no ARB files exist yet, no strings have
  been extracted from any of the ~15 screens, no language picker exists on
  `SettingsScreen`, and nothing reads `localeCode` yet (no `localeNotifier`
  wired into `main.dart`, unlike `themeModeNotifier`/`currencyNotifier`).
  Currency switching (the other half of the original combined request) is
  done — see the Component inventory's Currency formatting row.
- Domain/trademark check on "Stub" was a sanity-check web search only, not a
  legal clearance — do a real check before registering anything.
- **Full 20-30 image spike still not run, and the real ML Kit accuracy
  re-validation against it still hasn't been done either.** The result below
  is from 5 real images run through Apple's Vision framework, enough to
  validate the architecture decision but not a final accuracy number — and
  it's a different OCR engine from what actually ships
  (`google_mlkit_text_recognition`, see `MlKitTextRecognitionService`). Now
  that the real scan flow is wired up end to end, this is directly testable
  (run the same sample images through the real app on a physical device) but
  still hasn't been done. Worth doing both before shipping: revisit with a
  larger, more varied sample (different banks/apps/receipt formats, more
  lighting conditions), and confirm ML Kit's numbers actually match Vision's
  rather than assuming they transfer.
- ~~Pre-ship blocker: `LockScreen` is cosmetic only~~ — **resolved**:
  `LockScreen` now gates on a real `DeviceAuthService` (biometric-or-
  passcode via `local_auth`, single "Unlock" button — the OS handles
  falling back from biometric to passcode itself, so there's no separate
  passcode-only path). `main.dart`'s `_LockGateState` is a
  `WidgetsBindingObserver` that re-locks immediately whenever the app
  leaves the foreground (`paused`/`hidden`), so returning from the
  background always requires re-auth. A device with no biometric/passcode
  enrolled at all (`DeviceAuthService.isSupported()` false) skips the lock
  screen entirely — there's nothing to gate on. Not yet verified on a real
  device (see the new Open item below).
- ~~`ManualEntryScreen` has no UI trigger~~ — **resolved**: `LedgerScreen`
  now has a `FloatingActionButton` (`onAddManualEntry`) that opens it, wired
  through `RootShell._openManualEntry` to a real `TransactionRepository.create`
  call.
- **Account linking is Email-only so far.** Phase 2 added
  `AccountLinkService`/`SupabaseAccountLinkService`, `StubAccountLinkPanel`,
  and the one-time `BackupPromptScreen` (see the Supabase/auth section
  above); Profile & Settings then gave `ProfileScreen` a second entry point
  into the same panel for anyone who skipped the prompt. Apple/Google/Phone
  still remain visibly disabled pending external provider accounts. A user
  who skips the prompt and never later completes the Email link from
  Profile still loses their data if the device/app data is lost.
- **SMTP is still not configured.** `app/supabase/config.toml`'s
  `[auth.email.smtp]` block is present but entirely commented out, so
  Supabase's built-in dev-only email sender (rate-limited, not reliable in
  production) is still what actually sends the email-link confirmation. A
  real SMTP provider needs to be configured there before this ships to real
  users.
- ~~`AccountLinkService.linkStatusChanges` still has no subscriber~~ —
  **resolved**: `_ProfileScreenState` now holds a `StreamSubscription<bool>`
  on it (opened in `initState`, cancelled in `dispose`) that just calls an
  empty `setState`, since the status getters are read straight off the
  service. Driven by `HttpAccountLinkService`, whose getters only fill in
  after an async `/account` fetch — without this the screen showed "Member
  since —"/"Add your name" on first open and self-corrected only if some
  unrelated rebuild happened along. It also closes the original gap this item
  described: an external event (a confirmation link tapped while Profile is
  open) now refreshes the UI instead of needing `StubAccountLinkPanel`'s
  `onLinked` callback to have fired in-process.
- **Weekly summary has not been verified on a real device — timing
  especially.** Registered via `workmanager` (`scheduleWeeklySummary`), with
  `weeklySummaryCallbackDispatcher` re-initializing Supabase and computing
  the summary in a background isolate (see `weekly_summary_scheduler.dart`'s
  file-map entry). Nobody has confirmed it actually fires on a real device,
  and by design its timing is opportunistic — neither iOS nor Android
  guarantee a periodic background task runs at an exact clock time, so
  "every Sunday 6pm" is a target the first fire aims at, not a guarantee for
  every week after. If this ever needs to be tighter, revisit — there's no
  good fix on iOS specifically, it's a platform constraint.
- **Budget-limit-warning notifications have not been verified on a real
  device.** `LocalNotificationsService` (like `MlKitTextRecognitionService`/
  `LocalAuthDeviceAuthService`) has no automated test — it needs a real
  platform channel — so while the threshold-crossing logic itself
  (`highestNewlyCrossedThreshold`) is fully unit-tested and `RootShell`'s
  wiring is covered against `FakeNotificationService`, nobody has confirmed
  a real notification actually appears on a physical device, or that the
  permission-request flow behaves as expected on both iOS and Android 13+.
- **`LocalPrefs`'s notified-thresholds map grows unboundedly** — old
  budget periods are never pruned from the JSON blob stored under
  `budget_notified_thresholds`. Harmless at realistic scale (one small
  entry per category per period), but worth a cleanup pass eventually if
  it's ever a concern.
- **"Delete account" is a disabled row, not a real feature.**
  `SettingsScreen`'s Account section shows a permanently-disabled "Delete
  account — Coming soon" row (`StubCard`, no tap handler). Actually deleting
  a Supabase Auth user requires the `service_role` key server-side (a
  Supabase Edge Function), which doesn't exist yet — this is distinct from
  "Delete all data," which is implemented and does work (loops
  `list`/`delete` on transactions, then categories, via the two client-side
  repositories).
- **Real biometric/passcode lock has not been verified on a real device.**
  `LocalAuthDeviceAuthService` (like `MlKitTextRecognitionService`) has no
  automated test — it needs a real platform channel — so while
  `LockScreen`'s and `_LockGateState`'s logic are unit/widget-tested against
  `FakeDeviceAuthService`, nobody has confirmed Face ID/Touch ID/Android
  biometric-or-PIN actually gates the app, or that backgrounding-then-
  resuming a real build re-prompts, on a physical device.
- **CSV export has not been verified on a real device.** `csv_export.dart`'s
  `exportTransactionsCsv` (temp-file write via `path_provider` + OS share
  sheet via `share_plus`) has no automated test — only `buildTransactionsCsv`,
  the pure CSV-formatting half, is unit-tested — and per the plan's own
  Testing approach, no physical device was available during development to
  manually confirm the share sheet actually appears and produces a usable
  file end to end.
- **The actual deep-link confirmation flow has never been tested on a real
  device.** No physical device was available during development; the API
  usage was verified against the installed `gotrue`/`supabase_flutter`
  package source, but sending a real email and tapping a real confirmation
  link to confirm `com.stubapp.stub://` actually reopens the app has not
  been done.
- ~~`ScanScreen` still has no real camera/OCR behind it~~ — **resolved**:
  `ScanScreen` now captures a real image (`image_picker`), runs it through
  real on-device OCR (`MlKitTextRecognitionService`) and parsing
  (`parseReceiptLines`), and its result flows through `RootShell` into
  `EditEntryScreen(isCreating: true, ...)` for mandatory human review before
  a real `TransactionRepository.create` call.
- **Cloud-vision fallback for itemized/multi-column receipts is deliberately
  deferred, not built.** Per the OCR spike's own conclusion, on-device
  position-based reconstruction only partially fixes column-scrambled
  itemized receipts — the spike's decision was to route those to a cloud
  vision fallback rather than chase a perfect on-device heuristic, but this
  plan shipped on-device-only OCR with no such fallback, pending real usage
  data and a billing/API-account decision (see
  `docs/superpowers/specs/2026-09-06-receipt-scanner-design.md`'s "Out of
  scope" section). Itemized/multi-column receipts scanned today will just
  get whatever `parseReceiptLines` can extract from the scrambled reading
  order, corrected (or not) by the user on `EditEntryScreen`.
- **The full scan → OCR → save flow has never been verified end to end on a
  physical device.** `MlKitTextRecognitionService` doesn't run in `flutter
  test` (no platform channel) and ML Kit doesn't support the iOS Simulator on
  Apple Silicon (see the iOS setup notes above) — so while `receipt_parser.dart`'s
  parsing logic is unit-tested and `ScanScreen`'s UI flow is tested against
  `FakeTextRecognitionService`, nobody has pointed a real camera at a real
  receipt and confirmed a real transaction lands in Postgres.
- **Testing gap (Supabase path only)**: all 211 Flutter tests are unit/widget tests against in-memory
  fakes (`lib/data/fakes.dart`); the `Supabase*Repository` implementations
  have no automated test coverage against a real or local Supabase instance
  — only manual/CLI verification during implementation. Worth adding
  integration coverage (e.g. against the local `supabase start` stack)
  before relying on RLS/schema behavior in production without a human
  re-checking it. The custom backend does **not** have this gap — `server/test/`
  runs against a real Postgres and covers each route, RLS isolation both
  directions, and the error paths; the equivalent gap there is that the
  `Http*` Dart classes themselves have no tests (same convention as their
  `Supabase*` siblings).

## Real-device ML Kit findings (2026-09-07, receipt scanner follow-up)

First real end-to-end verification of the scan → OCR → parse flow on a
physical device (see `LocalAuthDeviceAuthService`/`MlKitTextRecognitionService`'s
"no automated test" caveats — this was the manual check those call for),
using a real Automercado receipt. Found and fixed three real code bugs
this session (all covered by new unit tests in `receipt_parser_test.dart`/
`image_orientation_test.dart`):
1. **Rotated capture wasn't corrected before OCR** — the Vision-framework
   spike above found "rotation is handled automatically," but that doesn't
   transfer to ML Kit: a portrait photo was fed to `MlKitTextRecognitionService`
   in raw sensor orientation, producing tall/narrow rotated bounding boxes
   that scrambled `receipt_parser.dart`'s row-based reconstruction. Fixed
   by `normalizeImageOrientation` (bakes in EXIF rotation before OCR).
2. **A label and its amount on the same printed row, OCR'd as two separate
   text blocks, never joined** — silently fell back to the largest number
   on the receipt (often the cash tendered) instead of the real total.
   Fixed by joining each reconstructed row into one string before matching.
3. **A receipt reference number matched the date regex** (`13-2-1520258`
   fit MM-DD-YYYY with an invalid month, producing garbage years like
   1521). Fixed by validating month/day plausibility.

**A confirmed, NOT-fixed limitation found the same session, after all
three fixes above**: on this same real receipt, ML Kit's character
recognition itself misread the total's printed `5,415.00` as `9.415.06`
(digit substitution + comma/period confusion) — no parsing logic can
recover a correct value when the underlying OCR characters are wrong at
the source. Separately, this specific receipt's total-block prints labels
(TOTAL/EFECTIVO/CAMBIO) more loosely spaced than their values, which can
still mis-pair even with fix #2 above (a column-rank-by-position fix was
considered and deliberately not built — real contamination risk pulling
in unrelated receipt text, and wouldn't have fixed the digit-misread
either). `ScanScreen`'s `_SourcePicker` now shows a tip ("lay it flat on a
well-lit surface and fill the frame") since photo quality is the actual
lever left to pull — worth revisiting the column-pairing idea only if a
strong real-world need shows up across multiple receipts, not this one.

## OCR/parsing spike — result (resolved)

Ran Apple's Vision framework (`VNRecognizeTextRequest`, `.accurate` level)
against 5 real images: 2 rotated/wrinkled photographed receipts, 1 receipt
photographed on a hole-punched metal surface, 2 dark-mode bank-notification
email screenshots. Script + raw output: `ocr-spike/ocr_test.swift`,
`ocr-spike/results/run1.txt`.

**Findings:**
- Rotation is handled automatically — no extra work needed for photos taken
  at an angle.
- Amount and date fields: correct on all 5 samples. Digital screenshots were
  essentially perfect end to end.
- One digit-insertion error on a long ID/account number, and a couple of
  character-level misreads on proper names — expect this class of error at
  low but nonzero rate.
- **The one structural failure**: itemized multi-column receipts (item / qty
  / unit price / total laid out in columns) get their lines read out of
  order. This is a known limitation of line-based OCR, not something a
  better photo fixes.
- Confidence scores are **not** a useful signal for the column-scrambling
  failure — Vision reported 1.00 confidence on every line even when the
  reading order was wrong. Confidence only reflects character-level
  certainty, not layout correctness.

**Decision: proceed with on-device-first, hybrid architecture — validated,
no pivot needed.**
1. Vision OCR is the default, primary path for everything (private, free,
   sub-second).
2. Route to cloud vision fallback **by receipt type, not by confidence
   score** — specifically itemized/multi-column receipts (detectable
   heuristically by many short numeric-heavy lines, or by category tagged at
   capture time), since confidence won't flag this failure mode.
3. Treat any long digit sequence that looks like an account/ID number as
   something to redact before storing/displaying, regardless of which
   parsing path produced it — don't trust it uncorrected.
4. The Edit-entry correction screen (already in the mockup) is mandatory
   insurance for both known failure modes above, not optional polish.

**Follow-up test — does position-based reconstruction fix the column
scrambling?** Partially. `ocr-spike/ocr_layout_test.swift` re-sorts Vision's
output by each line's bounding-box position (row-cluster by Y, then sort by
X within a row) instead of trusting default read order.
Result (`ocr-spike/results/layout_run1.txt`): the receipt's header
key/value fields (Cedula/Correo, dates, subtotal/tax/total) now pair up
correctly — a real, free improvement worth keeping. But this particular
receipt's itemized section splits each item across multiple
vertically-offset sub-lines (name / floating quantity / price), which a
simple row-threshold doesn't fully reconstruct. **Conclusion: build the
position-based reconstruction into the real parser (it's a genuine
improvement), but don't chase a "perfect" heuristic for itemized layouts —
keep the cloud-fallback-by-type routing from the decision above as the
actual safety net for that case**, rather than trying to solve it with
ever-more-specific layout heuristics.

**Tried two further variants to close the gap — neither converged, which
confirms the conclusion above rather than changing it:**
- *Overlap-with-any-row-member* (`ocr_layout_test2.swift`): chains
  transitively (A overlaps B, B overlaps C → A/B/C merge even though A and C
  don't actually overlap), which collapsed entire sections of the receipt
  into single giant rows. Worse than the simple threshold, not better.
- *Overlap-with-row-anchor-only* (`ocr_layout_test3.swift`): roughly a wash
  with the original simple-threshold version — fixes some lines, regresses
  others (e.g. a column header bleeding into the first item row).
- **Stopping heuristic iteration here.** Three attempts on the same failure
  mode with no clean win is a real signal, not a sign the right threshold
  hasn't been found yet. Ship the simple version (pass 2) as the on-device
  improvement, and treat itemized/multi-column receipts as a cloud-fallback
  case — don't sink further engineering time into perfecting this on-device.

## Visual design

Follow `DESIGN.md` in this folder for everything visual — colors, fonts,
gradient rules, button semantics, icon library. It's the single source of
truth; don't make a fresh visual judgment call when a rule already exists
there.

## Build with reusable elements, not one-offs

When something new needs to be built — a button, a card, a list row, a chip,
a badge, a progress bar, anything — **check whether an equivalent component
already exists first.** If it does, reuse it (extend with a prop/variant if
the new case is close-but-not-identical, the way `.cta` vs `.cta.save`
already works). If it genuinely doesn't exist yet, build it as a named,
reusable component from the start, not as inline one-off markup/styles — then
add it to the component inventory below so the next thing that needs it
reuses it instead of re-inventing it.

This applies regardless of what the underlying stack turns out to be
(SwiftUI views, React/React Native components, or the current HTML/CSS
mockup) — the principle is the same: **one definition per UI pattern, reused
everywhere that pattern appears.**

## Component inventory (update this list whenever a new one is added)

| Component | Where it's defined | Variants |
|---|---|---|
| Primary button | `.cta` (mockup) / `StubButton` (`lib/widgets/stub_button.dart`) | `StubButtonVariant.add` (blue), `StubButtonVariant.save` (green) |
| Destructive text link | `.danger-link` | red |
| Filter/category chip | `.chip` (mockup) / `StubChip` (`lib/widgets/stub_chip.dart`) | `.chip.active` (gradient fill) |
| Field row (label + value) | `.field-row` (mockup) / `StubFieldRow` (`lib/widgets/stub_field_row.dart`) | used in Edit entry and Manual entry screens |
| Progress bar | `.bar-track` / `.bar-fill` (mockup) / `StubProgressBar` (`lib/widgets/stub_progress_bar.dart`) | `.bar-fill.warn-fill` (over-budget, solid amber instead of gradient); fill animates 0 -> progress (700ms `TweenAnimationBuilder`) every time the widget mounts |
| Progress ring | `.ring` (mockup SVG, `.track` + `.fill`) / `StubProgressRing` (`lib/widgets/stub_progress_ring.dart`) | shared between dashboard hero and widget; fill animates 0 -> progress (700ms `TweenAnimationBuilder`) every time the widget mounts; optional `status` (`BudgetStatus`) swaps the gradient stroke for a flat warn/danger color |
| Budget status color | `budgetStatusForFraction`/`budgetStatusColor` (`lib/theme/budget_status.dart`) | not a widget itself — the shared normal/warning/danger threshold + color logic every progress-ish widget (`StubProgressBar`, `StubProgressRing`, `StubHeroAmount.percent`) and the plain percentage `Text`s on Ledger/Budgets/Category Detail all read from, so the red/amber cutoffs can't drift between screens |
| Card surface | `.surface`-based cards (mockup) / `StubCard` (`lib/widgets/stub_card.dart`) | `.hero-total`, `.categories`, list items |
| Bottom nav tab | `.tab` (mockup) / `StubBottomNav` + `StubNavItem` (`lib/widgets/stub_bottom_nav.dart`) | `.tab.active`, `.tab.scan-btn` (round, icon-only); activating a tab crossfades its icon+label (`AnimatedSwitcher`) and plays a one-shot scale bump (private `_BumpScale` helper in the same file) |
| Icon | `.src` (mockup) / `StubIcon` + `StubIcons` (`lib/widgets/stub_icon.dart`) | general-purpose recolorable SVG icon — transaction-source icons (receipt/payment app/bank) per `DESIGN.md` §7, plus nav, close, lock, camera, pencil icons used throughout the app |
| Transaction list tile | `StubTransactionTile` (`lib/widgets/stub_transaction_tile.dart`) | icon + description + amount + date |
| Hero numeral (gradient) | `.mono` + gradient override (mockup) / `StubHeroAmount` (`lib/widgets/stub_hero_amount.dart`) | the one "pop" number per screen (Ledger, Budgets); Manual Entry's editable amount uses the same `ShaderMask`/`gradPop` technique directly around its `TextField` instead, since `StubHeroAmount` can't stay editable; the number renders immediately in plain ink, then the gradient wipes left-to-right over it (~500ms) on mount |
| Logo mark | `StubLogo` (`lib/widgets/stub_logo.dart`) | torn stub + check, see DESIGN.md §7 — reuse this everywhere the mark appears (app icon, wordmark, splash), don't redraw the shape |
| Tap feedback wrapper | `StubPressable` (`lib/widgets/stub_pressable.dart`) | scale+fade press state; `ensureMinTapSize: true` pads the hit area to 44x44 without changing the visible child — used on every tappable widget/screen instead of `InkWell` |
| Currency formatting | `formatCurrency` (`lib/util/currency.dart`) | thousands separators, negative-safe, per-currency symbol via `CurrencyConfig.code` or an explicit override; `supportedCurrencies` (~39 codes) backs the `DropdownButton` currency pickers on `SettingsScreen` (global default) and `AddCategoryScreen` (per-category override) |
| Period picker | `StubPeriodPicker` (`lib/widgets/stub_period_picker.dart`) | weekly/monthly/yearly/custom via `StubChip`s; custom reveals start/end `StubFieldRow`s wired to `showDatePicker`; used by `AddCategoryScreen` |
| Provider row | `StubProviderRow` (`lib/widgets/stub_provider_row.dart`) | one tappable identity-provider row (icon + label); disabled variant shows a "Coming soon" tag, absorbs taps via `IgnorePointer`, and announces itself via `Semantics(enabled: false)` |
| Account-link panel | `StubAccountLinkPanel` (`lib/widgets/stub_account_link_panel.dart`) | the shared 4-provider (Email/Apple/Google/Phone) linking UI, with its own email sub-flow, validation, submit-guard, and error handling — used by both `BackupPromptScreen` and `ProfileScreen` (when anonymous), not re-implemented in either |
| Profile screen | `ProfileScreen` (`lib/screens/profile_screen.dart`) | Tab 2's real content — a tappable name row, status/`StubAccountLinkPanel`/stats cards + a Settings row, built entirely from `StubCard`/`StubIcon`/`StubPressable` and a plain `AlertDialog` (name edit) rather than introducing new primitives |
| Settings screen | `SettingsScreen` (`lib/screens/settings_screen.dart`) | theme picker (`StubChip`), notification toggles (`SwitchListTile.adaptive` — this project's first toggle-style control; no `Stub*` wrapper was built for it since Flutter's own adaptive switch already matches platform conventions), export/delete-all-data (`StubButton` + a plain `OutlinedButton` for the destructive action), disabled delete-account row (`StubCard`) |
| Category detail screen | `CategoryDetailScreen` (`lib/screens/category_detail_screen.dart`) | every transaction under one category — built entirely from `StubTransactionTile` and a plain `AppBar`/`ListView`, no new primitives; reached by tapping a category row on Ledger or a budget row on Budgets |
| Loading indicator | `StubLoadingIndicator` (`lib/widgets/stub_loading_indicator.dart`) | custom "receipt printing out of a slot" animation (`CustomPainter`, `gradPop` accent stripe), replacing Flutter's flat default blue `CircularProgressIndicator`; used everywhere the app shows an indeterminate loading/processing state (`RootShell`'s data-load and write-in-flight states, `ScanScreen`'s processing stage, `SettingsScreen`'s initial load, the app's startup gate) — `LockScreen`'s tiny inline button spinner is a deliberate exception, already custom-colored to match its button rather than defaulting to blue |

Before adding a new row to this table, check the list above — the answer is
often "reuse an existing one" rather than "add a new one."

The receipt scanner feature (real camera/photo-library capture, on-device
OCR, position-based parsing) added no new row here — `ScanScreen`'s source
and type pickers compose existing `StubButton`/`StubChip`/`StubIcon`, and
`EditEntryScreen`'s newly-functional merchant/amount editing reuses its
existing `StubFieldRow` plus a plain `AlertDialog`, not a new component.

## Reference implementation

`mockups.html` in this folder is the working proof of every rule in
`DESIGN.md` and this file. When in doubt, check what it actually does.
