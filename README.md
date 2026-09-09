# Stub

A screenshot-first budgeting app. No bank login, ever — instead of
connecting an account, you screenshot receipts, payment-app confirmations
(Venmo/Zelle-style), and bank-app screenshots, and Stub parses them into
transactions. Parsing runs on-device where possible, with cloud vision
fallback only for low-confidence reads (itemized/multi-column receipts).

## Status

All core screens are built and wired to real data: Ledger, Scan, Edit
Entry, Manual Entry, Budgets, Lock, Add Category, Category Detail, Profile,
and Settings. The app reads and writes real transactions/categories/budgets
through Supabase (anonymous auth by default, with an optional Email link to
back up the account), gates behind the device's real biometric/passcode
lock, and scans receipts/payment-app/bank screenshots through a real
capture → on-device OCR (Google ML Kit) → parse → human-review pipeline.
Categories carry a user-chosen icon and color, and budget progress
(individual categories and a combined "OVERALL" figure) is color-coded —
amber approaching the limit, red at or over it. See [`CLAUDE.md`](CLAUDE.md)'s
Open Items for what's still outstanding (cloud-vision fallback for
itemized receipts, language switching, notification scheduling, and a few
others not yet verified on a real device).

## Getting started

The Flutter project lives in [`app/`](app/).

```bash
cd app
flutter pub get
flutter run
```

Note: ML Kit (the on-device OCR used by the scan feature) doesn't support
the iOS Simulator on Apple Silicon — run on a real device to test scanning.

Useful commands (run from `app/`):

- `flutter analyze` — static analysis
- `flutter test` — widget/unit tests

## Tech stack

- **Flutter** (Dart) — iOS + Android from one codebase
- **Supabase** — Postgres + Auth + Storage backend
- **Google ML Kit** (`google_mlkit_text_recognition`) — on-device OCR

## Docs

- [`CLAUDE.md`](CLAUDE.md) — file map, architecture decisions, status, open items
- [`DESIGN.md`](DESIGN.md) — visual spec: colors, type, gradient rules, icon library, logo geometry
