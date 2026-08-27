# Profile & Settings Screens — Design Spec

**Goal:** Close the Profile tab gap (currently falls back to Ledger content)
with a real Profile screen, and add a Settings screen reachable from it,
covering theme, notification preferences, data export, and data deletion.

**Context:** Stub's bottom nav has 3 tabs — Home, Budgets, Profile — but
Profile has never had its own screen; tapping it shows Ledger content
with the nav highlight forced back to Home. This closes that gap.
Real account identity (Sign in with Apple/Google/Email/Phone, the
optional first-launch backup prompt) was deferred during the real-data-
foundation brainstorm as "Phase 2" — the user has asked for this spec to
be written first, then Phase 2 implemented, then this spec implemented
(so Profile's identity section can reflect Phase 2's real
account/link-status once it exists, rather than being built and then
immediately revised).

## Decisions from brainstorming (with rationale)

- **No HTML mockup step.** Unlike the original 7 screens, this is
  designed and built directly in Flutter, reusing DESIGN.md's existing
  component system rather than adding new one-off visual patterns.
- **Profile shows identity + lifetime stats + an entry into Settings** —
  not the full account-linking UI itself (that lives on Profile once
  Phase 2 exists, but isn't part of this spec's own screen design).
- **Settings covers**: theme (light/dark/system), notification
  preference toggles (inert — no notification system exists yet, and the
  screen must say so rather than imply otherwise), CSV data export via
  the OS share sheet, and a real "delete all data" action.
- **"Delete account" is explicitly NOT built here** — real account
  deletion needs a Supabase Edge Function with the service-role key
  (elevated privileges that can't safely run from the client), which is
  server-side infrastructure work outside "add screens" scope. Shown as
  a disabled/"coming soon" row rather than a button that doesn't work.
- **Theme and notification preferences persist locally** (device-level
  UI settings, not financial data) via a new `shared_preferences`
  dependency — not synced through Supabase, since there's no
  cross-device identity to sync to yet anyway.
- **Export format is CSV**, one row per transaction (date, merchant,
  amount, category, source), delivered via a new `share_plus` dependency
  (OS share sheet) — simplest, most portable, spreadsheet-ready format.

## New dependencies

- `share_plus` — hands a generated CSV file to the OS share sheet.
- `shared_preferences` — persists theme choice and notification-toggle
  state locally.

## Profile screen

- Header: identity placeholder (no real account yet — "Anonymous user"
  styling; Phase 2 replaces this with real identity/link status).
- Lifetime stats, computed from existing repository data (no schema
  changes needed):
  - **Total ever tracked** — sum of *all* transactions (`TransactionRepository.list()`
    already returns everything, unfiltered by period).
  - **Categories** — `data.categories.length`.
  - **Member since** — the anonymous auth user's `createdAt`
    (`Supabase.instance.client.auth.currentUser?.createdAt`), formatted.
- A row that pushes `SettingsScreen`.

## Settings screen

- **Theme**: a 3-way picker (Light/Dark/System), persisted via
  `shared_preferences`, read at app startup to override `main.dart`'s
  current hardcoded `themeMode: ThemeMode.system`.
- **Notifications**: toggles for things like "Budget limit warnings" and
  "Weekly summary" — persisted locally, but functionally inert (no
  notification system is wired up anywhere in the app yet). The screen
  must say so explicitly rather than implying the toggles do something
  today.
- **Export data**: builds a CSV string from `TransactionRepository.list()`
  (date, merchant, amount, category, source — one row per transaction)
  and shares it via `share_plus`.
- **Delete all data**: a confirmation dialog, then:
  1. delete every transaction (loop `TransactionRepository.delete`),
  2. delete every category (loop `CategoryRepository.delete` — budgets
     cascade-delete automatically via the schema's `ON DELETE CASCADE`
     from `budgets.category_id`),
  3. reload `RootShell` so the app reflects the now-empty state.
  No new repository methods needed — this composes the existing
  per-item interfaces.
- **Delete account**: a disabled/"coming soon" row. Not implemented —
  needs a Supabase Edge Function using the service-role key, which is
  out of scope for this spec.

## Data flow / integration

- `RootShell`'s tab-switch logic (`_tabIndex == 1` → Budgets, else →
  Ledger, with tab 2 previously forced to show Ledger content) gains a
  real third branch for tab 2 → `ProfileScreen`, fed the stats above
  (computed the same way `CategorySpend` colors already are — inside
  `build()`'s `FutureBuilder` callback, which has the `BuildContext`
  these computations may need).
- `ProfileScreen` pushes `SettingsScreen` via `Navigator`, passing
  through whatever repository access "delete all data" needs (the same
  `categoryRepository`/`transactionRepository` `RootShell` already
  holds).
- `main.dart` reads the persisted theme preference (via
  `shared_preferences`) before `runApp`, applying it as the initial
  `themeMode` instead of the current hardcoded `ThemeMode.system`.

## Out of scope (still, even after this spec)

- Real account identity / Sign in with Apple/Google/Email/Phone / the
  optional first-launch backup prompt (Phase 2 — implemented before this
  spec, per the user's requested ordering, but Phase 2 is its own spec,
  not part of this one).
- Real account/user deletion.
- A working notification system (the toggles are UI-only for now).
- Syncing any Settings preference across devices.
