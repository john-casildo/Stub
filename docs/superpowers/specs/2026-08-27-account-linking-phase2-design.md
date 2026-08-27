# Account Linking (Phase 2) — Design Spec

**Goal:** Give the anonymous session created in Phase 1 (real-data-
foundation) a path to a real, recoverable identity — without ever
requiring it, and without losing any existing data.

**Context:** Stub's identity model today is "anonymous session, silent,
no UI" (Phase 1). That was a deliberate product decision — matching
apps that never show a login screen — but it means a reinstall or new
device loses all data. Phase 2 makes upgrading to a real identity
possible and easy, but always optional and never a gate.

## Decisions from brainstorming (with rationale)

- **Only Email is built now.** Apple Sign-In, Google Sign-In, and Phone/
  SMS OTP all require external accounts/credentials (Apple Developer
  Program membership + Services ID; a Google Cloud OAuth client; a paid
  SMS provider like Twilio) that don't exist yet and can't be created by
  an agent — only by the project owner. Building UI for providers with
  no working backend would be dead weight. Each becomes its own small
  follow-up task once its account/credentials exist.
- **Apple/Google/Phone are shown in the UI anyway, visibly disabled**
  ("Coming soon") — signals the intended full set rather than looking
  incomplete, at the cost of needing a disabled-but-intentional visual
  treatment (not just a greyed-out button that looks broken).
- **The upgrade happens in place, never as a separate account.**
  Supabase's `updateUser(email: ...)` call on an existing anonymous
  session upgrades it to a permanent identity while preserving the same
  `auth.uid()` — every RLS policy in the schema is already scoped to
  `user_id = auth.uid()`, so this requires zero data migration and no
  schema change.
- **The first-launch prompt is a full screen, not a bottom sheet** —
  more emphasis, with a prominent "Skip" action so it doesn't read as a
  mandatory gate.
- **Shown exactly once**, tracked via a local flag (not a per-session
  check) — right after the very first unlock. If skipped, it's gone for
  good automatically; the same flow is always reachable afterward from
  Profile's "Account" section (Profile & Settings spec,
  `docs/superpowers/specs/2026-08-27-profile-and-settings-design.md`).

## Email linking flow

1. User taps "Continue with Email" → enters an email address.
2. App calls `Supabase.instance.client.auth.updateUser(UserAttributes(email: email))`
   on the current (anonymous) session.
3. Supabase sends a confirmation email to that address (existing rate-
   limit/OTP-length config from the real-data-foundation work applies
   unchanged — no new config needed).
4. User taps the confirmation link → the session is upgraded from
   anonymous to permanent **with the same `auth.uid()`** — every
   existing category/transaction/budget row remains valid and owned by
   the same user, since RLS never distinguished anonymous from permanent
   sessions in the first place.
5. The app listens for the Supabase auth state change
   (`onAuthStateChange`) and reflects "linked" status once the upgrade
   completes — no polling, no manual refresh needed.

## New UI

- **`BackupPromptScreen`** — full screen, shown automatically exactly
  once (a `shared_preferences` flag, e.g. `hasSeenBackupPrompt`, checked
  and set in `main.dart`'s lock-gate flow right after the first unlock).
  Prominent "Skip" action. Contains the same 4-provider linking UI
  described below.
- **Profile screen's "Account" section** (extends the Profile & Settings
  spec's Profile screen): shows current status — "Anonymous" or "Linked
  via [email address]" — and, only while still anonymous, the same
  4-provider linking UI inline.
- **The 4-provider linking UI** (shared between the prompt and Profile):
  Email (functional — opens an email-entry field, triggers the flow
  above), Apple/Google/Phone (visibly disabled rows, "Coming soon").

## Out of scope (tracked as explicit follow-ups, not "someday")

- Sign in with Apple — needs an Apple Developer Program membership + a
  Services ID + private key configured by the project owner first.
- Google Sign-In — needs a Google Cloud project + OAuth 2.0 client ID
  configured by the project owner first.
- Phone/SMS OTP — needs a paid SMS provider account (Twilio,
  MessageBird, etc.) configured by the project owner first.
- Any UI for *switching* or *unlinking* an identity once linked — this
  spec only covers the one-way anonymous-to-permanent upgrade.
- Cross-device sign-in flows (signing back in on a second device with an
  already-linked email) — this spec covers linking an existing anonymous
  session, not authenticating a fresh install against an existing
  identity. That's real, related work but a distinct flow worth its own
  pass once it's actually needed.
