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
| `app/lib/models/transaction.dart` | `Transaction`, `TransactionSource` — transaction models with category and amount |
| `app/lib/models/category_spend.dart` | `CategorySpend` — aggregated spend by category for dashboard |
| `app/lib/models/budget_limit.dart` | `BudgetLimit` — budget cap and alert threshold per category |
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
| `app/lib/screens/root_shell.dart` | `RootShell` — top-level navigation shell; tab-switches LedgerScreen/BudgetsScreen via StubBottomNav, pushes ScanScreen/EditEntryScreen via Navigator.push from the scan button/transaction tap |
| `app/lib/screens/ledger_screen.dart` | `LedgerScreen` — transaction list with category filtering and sample data |
| `app/lib/screens/scan_screen.dart` | `ScanScreen` — presentational confirm-card screen; no camera/OCR/parsing wired (deferred — see OCR/parsing spike section) |
| `app/lib/screens/edit_entry_screen.dart` | `EditEntryScreen` — correct/review transaction details (merchant, amount, category); no camera/re-capture feature |
| `app/lib/screens/manual_entry_screen.dart` | `ManualEntryScreen` — manual transaction entry form (built and tested, no UI trigger wired yet) |
| `app/lib/screens/budgets_screen.dart` | `BudgetsScreen` — budget overview dashboard with categories and progress rings |
| `app/lib/screens/lock_screen.dart` | `LockScreen` — app unlock flow, real entry point before RootShell |
| `app/test/widget_test.dart` | Smoke test — expanded with tests for all 6 real screens |
| `app/tool/generate_icon_test.dart` | Renders `StubLogo` to `assets/icon/icon.png` for `flutter_launcher_icons`; re-run if the mark changes |
| `app/supabase/config.toml` | Supabase CLI project config (linked to `jlygdlftvvgmekjcawgr`) |
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

**Status**: theme + all reusable components (`StubButton`, `StubLogo`, `StubIcon`, `StubCard`, `StubChip`, `StubFieldRow`, `StubProgressRing`, `StubProgressBar`, `StubTransactionTile`, `StubBottomNav`/`StubNavItem`) wired and verified (`flutter analyze` clean, 17 tests passing). All 6 real screens (Ledger, Scan, Edit Entry, Manual Entry, Budgets, Lock) ported from mockups and wired via `RootShell` navigation shell. `main.dart` now gates on `LockScreen` before showing the real app. Real app icon generated and installed for both iOS and Android via `tool/generate_icon_test.dart` (renders `StubLogo`'s exact geometry to `assets/icon/icon.png`) + `flutter_launcher_icons`. iOS build confirmed working end to end (`flutter build ios --debug --no-codesign` succeeds). Data is sample/static pending Supabase schema design and real camera/OCR pipeline wiring. **Open item**: `ManualEntryScreen` is built and tested in isolation but has no UI trigger wired yet (no button/gesture opens it from the main UI) — requires explicit design decision on where "add a cash transaction" lives in the navigation.

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

Schema not designed yet — next step: transactions, categories, budgets,
user profile tables + RLS policies (see the `supabase` skill's security
checklist before writing any policy — enable RLS on every table, use
`raw_app_meta_data` not `user_metadata` for authorization, remember UPDATE
policies need both USING and WITH CHECK).

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
| Progress bar | `.bar-track` / `.bar-fill` (mockup) / `StubProgressBar` (`lib/widgets/stub_progress_bar.dart`) | `.bar-fill.warn-fill` (over-budget, solid amber instead of gradient) |
| Progress ring | `.ring` (mockup SVG, `.track` + `.fill`) / `StubProgressRing` (`lib/widgets/stub_progress_ring.dart`) | shared between dashboard hero and widget |
| Card surface | `.surface`-based cards (mockup) / `StubCard` (`lib/widgets/stub_card.dart`) | `.hero-total`, `.categories`, list items |
| Bottom nav tab | `.tab` (mockup) / `StubBottomNav` + `StubNavItem` (`lib/widgets/stub_bottom_nav.dart`) | `.tab.active`, `.tab.scan-btn` (round, icon-only) |
| Icon | `.src` (mockup) / `StubIcon` + `StubIcons` (`lib/widgets/stub_icon.dart`) | general-purpose recolorable SVG icon — transaction-source icons (receipt/payment app/bank) per `DESIGN.md` §7, plus nav, close, lock, camera, pencil icons used throughout the app |
| Transaction list tile | `StubTransactionTile` (`lib/widgets/stub_transaction_tile.dart`) | icon + description + amount + date |
| Hero numeral (gradient) | `.mono` + gradient override (mockup) on `.hero-total .amount` / `.widget .wamount` / `.amount-display .big-amt` | the one "pop" number per screen |
| Logo mark | `StubLogo` (`lib/widgets/stub_logo.dart`) | torn stub + check, see DESIGN.md §7 — reuse this everywhere the mark appears (app icon, wordmark, splash), don't redraw the shape |

Before adding a new row to this table, check the list above — the answer is
often "reuse an existing one" rather than "add a new one."

## Reference implementation

`mockups.html` in this folder is the working proof of every rule in
`DESIGN.md` and this file. When in doubt, check what it actually does.
