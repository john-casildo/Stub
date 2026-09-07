# Receipt Scanner — Design Spec

**Goal:** Wire real camera/photo-library capture, on-device OCR, and
heuristic parsing behind `ScanScreen`, replacing its current hardcoded
sample data with a real scan-to-transaction flow.

**Context:** `ScanScreen` today is a static confirm-card screen fed a
hardcoded merchant/amount/category regardless of what's on screen —
tapping "Add to ledger" just pops the screen without writing anything.
`google_mlkit_text_recognition` is already a dependency but unused. The
OCR/parsing spike (see CLAUDE.md's "OCR/parsing spike" section) already
validated the architecture this spec implements: on-device-first OCR,
position-based line reconstruction, redaction of long digit sequences, and
a mandatory human-review step before anything is saved.

## Decisions from brainstorming (with rationale)

- **Capture: camera + photo library**, not camera-only — CLAUDE.md's own
  pitch is "screenshot-first" (payment-app/bank screenshots are typically
  already sitting in the photo library, not captured live).
- **On-device OCR only for this version — no cloud-vision fallback.**
  The spike's architecture calls for routing itemized/multi-column
  receipts to a cloud OCR fallback, but that needs its own paid API
  account/billing setup with no usage data yet to justify it. Deferred,
  not dropped — see the memory note below and the Open Items entry this
  spec adds to CLAUDE.md.
- **Mandatory review before saving, always.** OCR output always routes
  through `EditEntryScreen` (in a new create-mode) for confirmation/
  correction — never auto-saved. Matches the spike's explicit finding
  that manual correction is "mandatory insurance," not optional polish.
- **Reuse `EditEntryScreen` instead of rebuilding `ScanScreen`'s own
  editable form.** `EditEntryScreen` already has merchant/amount/category
  fields and a real save path; `ScanScreen`'s current confirm-card has no
  category picker at all. One editable-transaction form, not two.
- **Source type (Receipt / Payment app / Bank screenshot) is picked by
  the user**, not guessed from the image — simple, accurate, and doubles
  as the heuristic input a future cloud-fallback decision would need.
- **Account-number redaction is built now, not deferred** — unlike cloud
  fallback, this is a privacy commitment the app's pitch already makes
  ("no bank login, ever"), not an infrastructure/cost tradeoff.

## Pre-existing gap fixed as part of this work

`EditEntryScreen`'s merchant/amount `StubFieldRow`s are currently
`editable: true` in name only — that flag just draws a pencil icon; no
`onTap` is wired, so the fields aren't actually editable today (only the
category chips are). This must be fixed for OCR corrections to work at
all, so it's in scope here rather than filed as a separate bug.

## New dependency

- `image_picker` — camera + photo library capture, added via
  `flutter pub add image_picker` (never hand-typed into `pubspec.yaml`).

## New files/interfaces

- **`lib/data/text_recognition_service.dart`** — abstract
  `TextRecognitionService` with `Future<List<RecognizedLine>> recognizeText(String imagePath)`.
  `RecognizedLine` is a small plain data class (text + bounding box) —
  only what the parser's position-based reconstruction needs, not ML
  Kit's full API surface.
- **`lib/data/mlkit_text_recognition_service.dart`** — real
  `MlKitTextRecognitionService` wrapping `google_mlkit_text_recognition`.
- **`lib/data/fakes.dart`** — gains `FakeTextRecognitionService` (returns
  canned `RecognizedLine` lists), matching this file's existing pattern
  for every other repository/service.
- **`lib/util/receipt_parser.dart`** — pure function
  `ParsedReceipt parseReceiptLines(List<RecognizedLine> lines)`.
  `ParsedReceipt` holds nullable `merchant`/`amount`/`occurredAt` guesses
  (null when nothing confident was found). Fully unit-tested, no device
  or fake needed — same pure/platform split this codebase already
  established in `csv_export.dart`.
  - **Reconstruction**: row-cluster lines by Y position, then sort by X
    within each row (the spike's validated technique) before running any
    extraction heuristic.
  - **Amount**: scan reconstructed lines for currency-shaped numbers;
    prefer a line containing "total"/"amount due" (case-insensitive),
    else take the largest match.
  - **Date**: regex over common date formats; falls back to capture time
    if nothing matches.
  - **Merchant**: first non-empty reconstructed line — a simple,
    admittedly imperfect heuristic, acceptable because the review screen
    is mandatory regardless.
  - **Redaction**: any run of 8+ consecutive digits is masked (keep last
    4, e.g. `••••1234`) before merchant/amount extraction ever sees the
    text, so a raw account/ID number can never reach storage or the UI —
    applied unconditionally, not just on a "looks risky" heuristic.

## `EditEntryScreen` changes

- **Merchant/amount become genuinely editable**: tapping either field
  opens an inline `TextField` in place, matching Manual Entry's existing
  amount-editing pattern (`ShaderMask` + `TextField` for the amount; a
  plain `TextField` for merchant).
- **New `isCreating` mode** (`bool`, default `false`): when `true`, no
  Delete button is shown, and `onSave` passes back the full edited
  merchant/amount/category (not just category) so `RootShell` can call
  `TransactionRepository.create()` instead of `update()`. Additive to the
  existing constructor/callback shape — the existing edit-an-existing-
  transaction call site is unaffected.

## `ScanScreen` redesign

Replaces the current static confirm-card entirely with a capture +
processing flow:

1. On open, present the OS picker (camera vs. photo library) via
   `image_picker`.
2. Once an image is chosen, show a `StubChip` row to pick source type:
   Receipt / Payment app / Bank screenshot. Nothing pre-selected; the
   continue action stays disabled until one is picked.
3. Run `TextRecognitionService.recognizeText()` then
   `parseReceiptLines()`, showing a themed loading state (same
   Scaffold-wrapped pattern `RootShell`'s data-loading state uses) while
   it runs.
4. On completion, `RootShell` pushes `EditEntryScreen(isCreating: true, ...)`
   pre-filled with the parsed guess (nullable fields render as
   empty/placeholder — no separate "OCR failed" error path, since the
   review screen already covers "nothing was found" the same way it
   covers "found the wrong thing"), and pops `ScanScreen` off the stack
   so Back from Edit Entry returns to Ledger.
5. If the user cancels the image picker, `ScanScreen` closes back to
   wherever it was opened from — no error.

This drops the mockup's gradient check-stamp confirm-card visual, since
displaying parsed values is now `EditEntryScreen`'s job, not
`ScanScreen`'s.

## Error handling

- **Camera/photo-library permission denied**: caught, shown as a
  snackbar ("Camera access is needed to scan a receipt — enable it in
  Settings"), then closes back to wherever the scan was triggered from.
- **OCR call throws**: treated the same as "OCR found nothing" —
  proceeds to `EditEntryScreen` with empty fields rather than a scary
  error, since nothing has been saved yet and the review screen is the
  recovery path either way.
- **No source type selected**: no error state — the continue affordance
  simply stays disabled.

## Testing strategy

- `receipt_parser.dart` — fully unit-tested pure function: row
  reconstruction, amount/date/merchant extraction, and redaction, using
  fixture `RecognizedLine` data covering the spike's known cases (normal
  receipt, itemized/multi-column receipt, digital screenshot, a line
  containing a long digit run).
- `text_recognition_service.dart` — `FakeTextRecognitionService` lets
  `ScanScreen` be widget-tested without real ML Kit (ML Kit doesn't run
  on the iOS Simulator or in headless widget tests at all, per CLAUDE.md).
- `ScanScreen` — widget-tested against the fake service + a fake image
  picker result: image chosen → source picked → parsed result reaches
  the completion callback; permission-denied path.
- `EditEntryScreen` — extended tests for the new editable merchant/amount
  fields and `isCreating` mode.
- Manual/device-only verification: real ML Kit accuracy, real camera/
  photo-library permission prompts, real end-to-end scan-to-save on a
  physical device — consistent with this project's existing pattern for
  anything requiring OS-level integration.

## Out of scope (still, even after this spec)

- Cloud-vision fallback for itemized/multi-column receipts — deferred
  pending real usage data and a billing/API-account decision; see
  CLAUDE.md's Open Items.
- Any change to the spike's validated architecture — this spec
  implements it, it doesn't revisit the decision.
- A full 20-30 image re-validation of ML Kit's accuracy against the
  spike's Vision-framework numbers (already an open item, unaffected by
  this spec).
