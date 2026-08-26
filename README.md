# Stub

A screenshot-first budgeting app. No bank login, ever — instead of
connecting an account, you screenshot receipts, payment-app confirmations
(Venmo/Zelle-style), and bank-app screenshots, and Stub parses them into
transactions. Parsing runs on-device where possible, with cloud vision
fallback only for low-confidence reads (itemized/multi-column receipts).

## Status

All 6 core screens are built and wired: Ledger, Scan, Edit Entry, Manual
Entry, Budgets, and Lock. Data is currently sample/static — real camera/OCR
pipeline wiring and Supabase-backed data are the next milestones. See
[`CLAUDE.md`](CLAUDE.md)'s Open Items for the current pre-ship blockers.

## Getting started

The Flutter project lives in [`app/`](app/).

```bash
cd app
flutter pub get
flutter run
```

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
