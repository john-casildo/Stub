# Siri Shortcuts Quick-Log — Design Spec

**Goal:** Let a user log an expense via an iOS Shortcuts automation (e.g.
triggered by opening Wallet right after an Apple Pay tap-to-pay), without
opening the app and navigating to Manual Entry themselves first.

**Context:** Prompted by a competitor app screenshot showing an
"Automatically track expenses when you use Apple Pay" Shortcuts setup flow
that appears to save an expense with no further user input. Investigated as
a spike first — conclusion: iOS has no trigger tied to real Apple Pay
transaction data (amount/merchant) for arbitrary bank cards; that level of
"automatic" is either Apple-Card-specific or requires scraping bank
notification text, which cuts against this app's own "no bank login, ever"
trust pitch. What's genuinely buildable is a **quick-log shortcut**: a
Shortcuts action that hands off amount/merchant to the app for a one-tap
confirm, not a fully silent background write.

## Decisions from brainstorming (with rationale)

- **Deep-link into a pre-filled review screen, not a silent background
  save.** Matches this app's existing rule that OCR-scanned entries are
  never auto-saved without a human glance first (`receipt_parser.dart`'s
  spec: "manual correction is mandatory insurance, not optional polish").
  Input typed in a rush via Shortcuts deserves the same treatment. This
  also avoids needing a native Swift Supabase client or a headless
  Flutter engine — the intent just opens a URL, and the existing Flutter
  app does everything else through its normal, already-tested save path.
- **No category parameter on the Shortcuts action itself.** A dynamic
  category picker in the Shortcuts UI would require the native Swift
  intent to read the user's live category list from Supabase — real
  native networking/auth-session code for a small convenience. Category
  is picked in-app instead, after the deep link opens `ManualEntryScreen`
  (defaulting to whichever category was last used, matching that
  screen's existing default-to-first-category behavior otherwise).
- **Reuse the existing `com.stubapp.stub://` URL scheme** (currently only
  used for the Supabase email-link auth callback) rather than registering
  a second scheme.

## Out of scope

- Fully automatic, silent expense capture tied to real Apple Pay
  transaction data — not something arbitrary (non-Apple-Card) bank cards
  expose to third-party apps.
- Any bank/card notification content reading — would undermine "no bank
  login, ever."
- A dynamic category picker inside the Shortcuts UI.
- Android equivalent (Shortcuts/App Intents is an iOS-only concept; a
  future Android version of this idea would use a different mechanism
  entirely — App Actions/Widgets — and is not designed here).

## New files/interfaces

- **`ios/Runner/LogExpenseIntent.swift`** (new) — an `AppIntent` (Apple's
  App Intents framework, iOS 16+) exposing two Shortcuts parameters:
  `amount` (required number) and `merchant` (optional text). `perform()`
  builds `com.stubapp.stub://log-expense?amount=<amount>&merchant=<merchant>`
  (merchant URL-encoded, omitted if blank) and opens it via
  `UIApplication.shared.open(...)`. Also needs an `AppShortcutsProvider`
  conformance (a small, separate Swift type) so the shortcut is
  discoverable in the Shortcuts app/Spotlight without the user manually
  building it from scratch. **Exact App Intents API syntax must be
  verified against current Apple documentation during implementation** —
  it has shifted across iOS 16/17/18 releases; do not rely on
  possibly-stale training knowledge for the precise protocol
  requirements.
- **`lib/util/deep_link.dart`** (new) — pure parsing: `ParsedDeepLink?
  parseDeepLink(Uri uri)`, recognizing the `log-expense` host/path and
  extracting `amount`/`merchant` (both nullable — a malformed or missing
  amount just means `ManualEntryScreen` opens at its normal `$0.00`
  default rather than failing). Fully unit-testable, no platform channel
  needed — same pure/platform split as `receipt_parser.dart`/
  `csv_export.dart`.
- **`app_links` package** (already present transitively via existing
  deps — add directly via `flutter pub add app_links`, never hand-typed
  into `pubspec.yaml`) — used in `main.dart`/`StubApp` to listen for
  incoming links (`AppLinks().uriLinkStream`, plus `getInitialLink()` for
  a cold launch triggered by the link itself) and hand matching ones to
  `parseDeepLink`. Coexists with `supabase_flutter`'s own internal
  listener for the auth-callback path — both independently receive the
  same OS-level incoming URL and only act on the path they recognize.
- **`ManualEntryScreen`** gains optional `initialAmount`/`initialMerchant`
  constructor parameters, pre-filling `_amountController`/
  `_merchantController` when set (both already `TextEditingController`s
  with defaults — this is an additive, low-risk change to an existing
  widget, not a rewrite).
- **`RootShell`** gains the actual navigation: on a recognized
  `log-expense` link, push `ManualEntryScreen` pre-filled, same
  `_openManualEntry` category-list/zero-categories-guard path every other
  entry point into that screen already uses.

## Data flow

1. User's Shortcuts automation runs "Log expense to Stub" (built from the
   `AppShortcutsProvider`-provided template), typically prompting for the
   amount via Shortcuts' own "Ask Each Time" input.
2. `LogExpenseIntent.perform()` opens
   `com.stubapp.stub://log-expense?amount=12.50&merchant=Starbucks`.
3. iOS launches (cold) or foregrounds (warm) Stub with that URL.
4. `app_links`' stream (or `getInitialLink()` on cold launch) delivers the
   `Uri` to a listener in `main.dart`/`StubApp`.
5. `parseDeepLink` recognizes it and extracts `amount: 12.50, merchant:
   'Starbucks'`.
6. **If the app is locked or mid-startup**, the parsed link is held as a
   plain nullable field on `_StubAppState` (not a queue — a second link
   before the first is consumed just replaces it), since that's the
   widget that already owns lock/unlock state and decides when
   `RootShell` gets built at all. `RootShell` is only ever constructed
   post-unlock (`_buildHome()`'s existing gating), so `_StubAppState`
   passes the pending value into `RootShell` as a one-time nullable
   constructor field (e.g. `pendingDeepLinkAmount`/`pendingDeepLinkMerchant`)
   and clears it immediately after passing it along, so a later rebuild
   (e.g. backgrounding/re-locking) doesn't re-open `ManualEntryScreen` a
   second time for the same link.
7. `RootShell` consumes that pending value once (in `initState` /
   whichever lifecycle hook it already uses for one-time startup
   actions) and pushes `ManualEntryScreen(initialAmount: 12.50,
   initialMerchant: 'Starbucks', categories: ...)` — same zero-categories
   snackbar guard as `_openManualEntry` already has today if there are no
   categories yet.
8. User picks/confirms the category, taps "Save entry" — same
   `TransactionRepository.create` path every other manual entry uses.
   Nothing in this feature bypasses that save path or writes directly.

## Error handling

- Malformed/missing `amount` in the link → `ManualEntryScreen` opens at
  its existing `$0.00` default instead of failing outright, matching the
  rest of the app's "never crash on bad input" posture.
- A `log-expense` link arriving with zero categories in the account →
  same snackbar ("Add a category first, then log an expense.") the
  existing FAB entry point already shows, not a new error path.
- Any other `com.stubapp.stub://` link (e.g. the existing auth-callback
  path) is left alone — the new listener only acts on `log-expense`.

## Testing

- `parseDeepLink` — pure, fully unit-tested (valid link, missing amount,
  missing merchant, malformed amount, unrelated path/host).
- `ManualEntryScreen`'s new `initialAmount`/`initialMerchant` params —
  widget-tested against `FakeTransactionRepository`, same pattern as its
  existing tests.
- `RootShell`'s pending-link-then-consume-once wiring — widget-tested by
  simulating an incoming link before and after unlock.
- **Not automatable**: the real `LogExpenseIntent` Swift code, the actual
  Shortcuts automation setup UX, and the true end-to-end "run a Shortcut →
  Stub opens pre-filled" flow all need a physical device — same story as
  `MlKitTextRecognitionService`/`LocalAuthDeviceAuthService`/
  `LocalNotificationsService` elsewhere in this app. Verify manually
  before considering this shipped.

## Open items this spec would add to CLAUDE.md once implemented

- Android has no equivalent in this pass — iOS-only feature.
- The exact App Intents API surface needs verifying against current Apple
  docs at implementation time, not assumed from this spec.
- Not verified on a real device (real Shortcuts setup + real deep-link
  handoff) until manually tested post-implementation.
