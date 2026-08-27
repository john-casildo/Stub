# Stub — Project Instructions

## File map — check here before exploring/globbing the project

Everything not listed below is either generated boilerplate (Android/iOS
Flutter scaffold, `.dart_tool/`, `build/`, `Pods/`, `.symlinks/`) or a
one-off spike output — safe to ignore unless a task specifically concerns
it.

| Path | What's there |
|---|---|
| `CLAUDE.md` (repo root) | This file — process rules, decisions, status |
| `DESIGN.md` (repo root) | The full visual spec — colors, type, gradient rules, icon library, logo geometry. Load before any visual change. |
| `mockups.html` (repo root) | The 7-screen HTML mockup, published as artifact "Stub" — the visual reference implementation |
| `logo-concepts.html` (repo root) | The 4 logo directions explored before picking torn-stub-+-check, published as artifact "Stub Marks" |
| `app/` | The real Flutter project root (`pubspec.yaml`, `lib/`, `ios/`, `android/`) |
| `app/lib/main.dart` | App entry point — Supabase init, theme wiring, gates on LockScreen before showing RootShell |
| `app/lib/theme/colors.dart` | Every color token, copied from DESIGN.md §2 — never invent a color elsewhere |
| `app/lib/theme/text.dart` | The 3-font system (Archivo/Domine/Unbounded) from DESIGN.md §1 |
| `app/lib/theme/app_theme.dart` | Wires colors.dart + text.dart into Flutter's light/dark ThemeData |
| `app/lib/config/supabase_config.dart` | Supabase URL + publishable key (client-safe; never put a secret key here) |
| `app/lib/models/transaction.dart` | `Transaction`, `TransactionSource` — transaction model; now also carries `categoryId`, `fromRow`/`toInsertRow` (Postgres row mapping), and `copyWith` |
| `app/lib/models/category_spend.dart` | `CategorySpend` — aggregated spend by category for dashboard |
| `app/lib/models/budget_limit.dart` | `BudgetLimit`, `BudgetPeriodType` (weekly/monthly/yearly/custom) — budget cap per category, `fromRow` maps a `budget_progress` view row |
| `app/lib/models/category.dart` | `Category` — id/name, `fromRow`/`toInsertRow` |
| `app/lib/theme/category_colors.dart` | `categoryColor(index, brightness)` — deterministic 6-color swatch cycle for category rows, light/dark palettes |
| `app/lib/data/category_repository.dart` | `CategoryRepository` — abstract interface (`list`/`create`/`delete`) |
| `app/lib/data/transaction_repository.dart` | `TransactionRepository` — abstract interface (`list`/`create`/`update`/`delete`) |
| `app/lib/data/budget_repository.dart` | `BudgetRepository` — abstract interface (`list`/`create`) |
| `app/lib/data/fakes.dart` | `FakeCategoryRepository`, `FakeTransactionRepository`, `FakeBudgetRepository` — in-memory test doubles. `FakeBudgetRepository` takes an *optional* `FakeCategoryRepository` link: when given, it resolves real category names on `create()` and drops budgets from `list()` once their category is gone (mirroring the schema's `ON DELETE CASCADE`); without it, falls back to a placeholder name and no cascade — a deliberate, non-naive design, not a plain in-memory store |
| `app/lib/data/supabase_category_repository.dart` | `SupabaseCategoryRepository` — real Postgres-backed `CategoryRepository` via `supabase_flutter` |
| `app/lib/data/supabase_transaction_repository.dart` | `SupabaseTransactionRepository` — real Postgres-backed `TransactionRepository`; joins `categories(name)` on read |
| `app/lib/data/supabase_budget_repository.dart` | `SupabaseBudgetRepository` — real Postgres-backed `BudgetRepository`; reads from the `budget_progress` view |
| `app/lib/widgets/stub_button.dart` | `StubButton` — Add/Save variant button, see Component inventory below |
| `app/lib/widgets/stub_logo.dart` | `StubLogo` — the torn-stub-+-check mark, DESIGN.md §7 |
| `app/lib/widgets/stub_icon.dart` | `StubIcon`, `StubIcons` — recolorable Tabler SVG icon widget; `StubIcons` holds 10 icons (home, camera, chartBar, userCircle, receipt, cashBanknote, buildingBank, lock, pencil, x) used across nav, close buttons, and screens — not limited to transaction-source badges |
| `app/lib/widgets/stub_card.dart` | `StubCard` — reusable card surface for dashboard, category rows, transaction tiles |
| `app/lib/widgets/stub_chip.dart` | `StubChip` — category filter chip with active/gradient state |
| `app/lib/widgets/stub_field_row.dart` | `StubFieldRow` — label + value pair, used in Edit Entry and Manual Entry screens |
| `app/lib/widgets/stub_progress_ring.dart` | `StubProgressRing` — circular progress ring, shared between dashboard hero and widget |
| `app/lib/widgets/stub_progress_bar.dart` | `StubProgressBar` — linear progress bar with over-budget warning state |
| `app/lib/widgets/stub_transaction_tile.dart` | `StubTransactionTile` — list row for a single transaction (icon, description, amount, date) |
| `app/lib/widgets/stub_bottom_nav.dart` | `StubBottomNav`, `StubNavItem` — bottom navigation bar with 3 tabs (Home/Budgets/Profile) + a separate fixed round scan button (not one of the 3 tabs) |
| `app/lib/widgets/stub_hero_amount.dart` | `StubHeroAmount` — big gradient-text currency number (`ShaderMask` + `StubColors.gradPop`), used for every hero amount so blue never renders flat there |
| `app/lib/widgets/stub_pressable.dart` | `StubPressable` — press feedback (scale+fade) wrapper for tappable widgets, with an optional 44x44 minimum tap-target guarantee; used instead of `InkWell` since most tappable surfaces here have an opaque gradient/solid fill that would hide a Material ripple |
| `app/lib/widgets/stub_period_picker.dart` | `StubPeriodPicker` — weekly/monthly/yearly/custom period selector (built from `StubChip` + `StubFieldRow`); shows start/end date fields (via `showDatePicker`) only when Custom is selected |
| `app/lib/util/currency.dart` | `formatCurrency` — shared thousands-separator currency formatter (negative-safe), used by every screen/widget that displays money |
| `app/lib/screens/root_shell.dart` | `RootShell` — top-level navigation shell; loads real data from its three injected repositories (`categoryRepository`/`transactionRepository`/`budgetRepository`) via a `FutureBuilder` (`_load`/`_reload`, with loading and error+retry states), tab-switches LedgerScreen/BudgetsScreen via StubBottomNav (cross-fades between them via `AnimatedSwitcher`), and pushes ScanScreen (still a no-op stub — no repository write)/EditEntryScreen/ManualEntryScreen/AddCategoryScreen via Navigator.push, the latter three each wired to a real repository write followed by `_reload()`; category deletion surfaces the Postgres `ON DELETE RESTRICT` error (code `23503`) as a snackbar instead of crashing |
| `app/lib/screens/ledger_screen.dart` | `LedgerScreen` — hero "left to spend" progress ring, per-category spend list (colored via `categoryColor`), and recent transactions, now fed real data by `RootShell`; has a `FloatingActionButton` (`onAddManualEntry`) that opens `ManualEntryScreen`; still no category filtering |
| `app/lib/screens/scan_screen.dart` | `ScanScreen` — presentational confirm-card screen; no camera/OCR/parsing wired (deferred — see OCR/parsing spike section) |
| `app/lib/screens/edit_entry_screen.dart` | `EditEntryScreen` — correct/review transaction details (merchant, amount, category); saves/deletes via `TransactionRepository` through `RootShell`; no camera/re-capture feature |
| `app/lib/screens/manual_entry_screen.dart` | `ManualEntryScreen` — manual transaction entry form; now reachable from `LedgerScreen`'s FAB (see Open items — the "no UI trigger" gap is resolved) and writes via `TransactionRepository` |
| `app/lib/screens/add_category_screen.dart` | `AddCategoryScreen` — new-category form (name, limit amount, `StubPeriodPicker` for the budget period); `onSave` creates the category then the budget via `CategoryRepository`/`BudgetRepository`, opened from `BudgetsScreen`'s add-category tap |
| `app/lib/screens/budgets_screen.dart` | `BudgetsScreen` — budget overview dashboard with an overall `StubProgressBar` and per-category `StubProgressBar` rows; each row has a delete `IconButton` (`onDeleteCategory`) and there's an add-category tap (`onAddCategory`) that opens `AddCategoryScreen` |
| `app/lib/screens/lock_screen.dart` | `LockScreen` — app unlock flow, real entry point before RootShell |
| `app/test/widget_test.dart` | App-level smoke test — boots locked, unlocks into the real ledger, `pumpAndSettle`s past the post-unlock async data load |
| `app/test/models_test.dart` | Tests for `Transaction`/`CategorySpend`/`BudgetLimit` |
| `app/test/data/fakes_test.dart` | Tests for `FakeCategoryRepository`/`FakeTransactionRepository`/`FakeBudgetRepository` create/list/update/delete in-memory behavior |
| `app/test/theme/category_colors_test.dart` | Tests for `categoryColor`'s deterministic cycling and light/dark divergence |
| `app/test/widgets/*_test.dart` | One test file per reusable widget (`stub_bottom_nav`, `stub_card`, `stub_chip`, `stub_field_row`, `stub_hero_amount`, `stub_icon`, `stub_period_picker`, `stub_pressable`, `stub_progress_bar`, `stub_progress_ring`, `stub_transaction_tile`) — same basename as the widget under `lib/widgets/` |
| `app/test/screens/*_test.dart` | One test file per screen (`add_category_screen`, `budgets_screen`, `edit_entry_screen`, `ledger_screen`, `lock_screen`, `manual_entry_screen`, `root_shell`, `scan_screen`) — same basename as the screen under `lib/screens/` |
| `app/test/util/currency_test.dart` | Tests for `formatCurrency`, including the negative-amount case |
| `app/tool/generate_icon_test.dart` | Renders `StubLogo` to `assets/icon/icon.png` for `flutter_launcher_icons`; re-run if the mark changes |
| `app/supabase/config.toml` | Supabase CLI project config (linked to `jlygdlftvvgmekjcawgr`); `[auth]` has `enable_anonymous_sign_ins = true`, pushed to and confirmed working against the real remote project |
| `app/supabase/migrations/20260826222620_real_data_foundation.sql` | The real schema: `categories`/`budgets`/`transactions` tables (all with RLS, `select`/`insert`/`update`/`delete` "own rows only" policies keyed on `auth.uid()`), plus the `budget_progress` view (`security_invoker`) that joins each budget to its category name and sums transactions within the current period (weekly/monthly/yearly computed from `now()`, custom uses `period_start`/`period_end`) |
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

**Status**: theme + all reusable components (`StubButton`, `StubLogo`, `StubIcon`, `StubCard`, `StubChip`, `StubFieldRow`, `StubProgressRing`, `StubProgressBar`, `StubTransactionTile`, `StubBottomNav`/`StubNavItem`, `StubHeroAmount`, `StubPressable`, `StubPeriodPicker`) wired and verified (`flutter analyze` clean, 50 tests passing). All 7 real screens (Ledger, Scan, Edit Entry, Manual Entry, Budgets, Lock, Add Category) ported/added and wired via `RootShell` navigation shell. `main.dart` now gates on `LockScreen` before showing the real app.

The app now reads and writes **real data** through Supabase, not sample data: `main.dart` calls `Supabase.initialize()` then `_ensureSession()` (silently `signInAnonymously()`s if there's no existing session — anonymous auth is enabled and verified working against the real remote project, see the Supabase section below), then constructs the three real `Supabase*Repository` implementations and threads them down through `StubApp` → `_LockGate` → `RootShell`. `RootShell` loads categories/transactions/budgets on init, reloads after every write, and wires Ledger's manual-entry FAB, Edit Entry's save/delete, and a new Add Category screen (name + limit + period, via `StubPeriodPicker`) all the way through to Postgres. There is no user-facing profile/account screen yet and no Apple/Google/Email/Phone sign-in — anonymous auth is the whole identity story today; linking a persistent identity (Phase 2) is the next real step, not yet started. Camera/OCR capture is still not wired (see `ScanScreen`'s entry above) — `ScanScreen` still uses a hardcoded sample merchant/amount/category rather than a real scan result.

Real app icon generated and installed for both iOS and Android via `tool/generate_icon_test.dart` (renders `StubLogo`'s exact geometry to `assets/icon/icon.png`) + `flutter_launcher_icons`. iOS build confirmed working end to end (`flutter build ios --debug --no-codesign` succeeds).

**Testing approach**: all 50 tests are pure-Dart widget/unit tests run via `flutter test` against the in-memory fakes in `lib/data/fakes.dart` (or, for models/utils, no backend at all) — there is no integration test suite that hits the real Supabase project. The `Supabase*Repository` implementations (`lib/data/supabase_*_repository.dart`) are exercised only by manual/CLI verification during implementation (recorded in the task reports under `.superpowers/sdd/2026-08-26-real-data-foundation/`), not by an automated test run against the live database.

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
This is the entire identity story right now — there is no Apple/Google/
Email/Phone sign-in and no account-linking flow; an anonymous user's data
lives only as long as that device's session persists. Phase 2 (linking a
persistent identity — Apple/Google/Email/Phone) is the next step, not yet
started.

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

- Domain/trademark check on "Stub" was a sanity-check web search only, not a
  legal clearance — do a real check before registering anything.
- **Full 20-30 image spike still not run** — the result below is from 5 real
  images, enough to validate the architecture decision but not a final
  accuracy number. Worth revisiting with a larger, more varied sample
  (different banks/apps/receipt formats, more lighting conditions) before
  shipping.
- **Pre-ship blocker: `LockScreen` is cosmetic only.** `main.dart`'s
  `_unlocked` flag is set by either button — "Use passcode" unlocks with
  no passcode entry, there's no `AppLifecycleState` observer so the app
  never re-locks after backgrounding, and the `local_auth` dependency is
  present but unused. The screen's copy ("Your ledger, kept private")
  currently promises privacy the app doesn't provide. Must wire real
  biometric/passcode auth (and re-lock on background) before shipping —
  this is a real security gap, not a stylistic one.
- ~~`ManualEntryScreen` has no UI trigger~~ — **resolved**: `LedgerScreen`
  now has a `FloatingActionButton` (`onAddManualEntry`) that opens it, wired
  through `RootShell._openManualEntry` to a real `TransactionRepository.create`
  call.
- **No real account/identity yet.** The app only ever signs in anonymously
  (`_ensureSession()` in `main.dart`) — there's no Apple/Google/Email/Phone
  sign-in, no account-linking, and no profile screen (Tab 2 "Profile" in
  `RootShell` currently just falls back to rendering the Ledger content —
  see the comment in `root_shell.dart`'s `build()`). Losing the device/app
  data means losing the anonymous session's data with no recovery path.
  This is the planned Phase 2 next step, not started.
- **`ScanScreen` still has no real camera/OCR behind it.** `RootShell._openScan`
  pushes it with a hardcoded sample merchant/amount/category
  (`'Corner Market'` / `18.42` / `'Groceries'`) regardless of what's on
  screen — tapping "Add to ledger" there does not currently create a real
  transaction row (`onAddToLedger` just pops the screen). Only Manual Entry
  and Edit Entry actually write to Postgres today.
- **Testing gap**: all 50 tests are unit/widget tests against in-memory
  fakes (`lib/data/fakes.dart`); the `Supabase*Repository` implementations
  have no automated test coverage against a real or local Supabase instance
  — only manual/CLI verification during implementation. Worth adding
  integration coverage (e.g. against the local `supabase start` stack)
  before relying on RLS/schema behavior in production without a human
  re-checking it.

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
| Progress ring | `.ring` (mockup SVG, `.track` + `.fill`) / `StubProgressRing` (`lib/widgets/stub_progress_ring.dart`) | shared between dashboard hero and widget; fill animates 0 -> progress (700ms `TweenAnimationBuilder`) every time the widget mounts |
| Card surface | `.surface`-based cards (mockup) / `StubCard` (`lib/widgets/stub_card.dart`) | `.hero-total`, `.categories`, list items |
| Bottom nav tab | `.tab` (mockup) / `StubBottomNav` + `StubNavItem` (`lib/widgets/stub_bottom_nav.dart`) | `.tab.active`, `.tab.scan-btn` (round, icon-only); activating a tab crossfades its icon+label (`AnimatedSwitcher`) and plays a one-shot scale bump (private `_BumpScale` helper in the same file) |
| Icon | `.src` (mockup) / `StubIcon` + `StubIcons` (`lib/widgets/stub_icon.dart`) | general-purpose recolorable SVG icon — transaction-source icons (receipt/payment app/bank) per `DESIGN.md` §7, plus nav, close, lock, camera, pencil icons used throughout the app |
| Transaction list tile | `StubTransactionTile` (`lib/widgets/stub_transaction_tile.dart`) | icon + description + amount + date |
| Hero numeral (gradient) | `.mono` + gradient override (mockup) / `StubHeroAmount` (`lib/widgets/stub_hero_amount.dart`) | the one "pop" number per screen (Ledger, Budgets); Manual Entry's editable amount uses the same `ShaderMask`/`gradPop` technique directly around its `TextField` instead, since `StubHeroAmount` can't stay editable; the number renders immediately in plain ink, then the gradient wipes left-to-right over it (~500ms) on mount |
| Logo mark | `StubLogo` (`lib/widgets/stub_logo.dart`) | torn stub + check, see DESIGN.md §7 — reuse this everywhere the mark appears (app icon, wordmark, splash), don't redraw the shape |
| Tap feedback wrapper | `StubPressable` (`lib/widgets/stub_pressable.dart`) | scale+fade press state; `ensureMinTapSize: true` pads the hit area to 44x44 without changing the visible child — used on every tappable widget/screen instead of `InkWell` |
| Currency formatting | `formatCurrency` (`lib/util/currency.dart`) | thousands separators, negative-safe; used everywhere a screen displays a dollar amount |
| Period picker | `StubPeriodPicker` (`lib/widgets/stub_period_picker.dart`) | weekly/monthly/yearly/custom via `StubChip`s; custom reveals start/end `StubFieldRow`s wired to `showDatePicker`; used by `AddCategoryScreen` |

Before adding a new row to this table, check the list above — the answer is
often "reuse an existing one" rather than "add a new one."

## Reference implementation

`mockups.html` in this folder is the working proof of every rule in
`DESIGN.md` and this file. When in doubt, check what it actually does.
