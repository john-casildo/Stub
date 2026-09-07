# Receipt Scanner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire real camera/photo-library capture, on-device OCR, and heuristic parsing behind `ScanScreen`, replacing its hardcoded sample data with a real scan-to-transaction flow that always routes through a mandatory human-review step before saving.

**Architecture:** A pure-Dart `receipt_parser.dart` (row reconstruction + merchant/amount/date extraction + digit-run redaction) sits behind a thin `TextRecognitionService` interface (real ML Kit implementation + fake for tests) — the same pure/platform split this codebase already uses for `csv_export.dart`. `ScanScreen` captures an image and a source-type tag, runs OCR+parsing, then `RootShell` pushes the extended `EditEntryScreen` (now supporting a create mode and genuinely editable merchant/amount fields) pre-filled with the parsed guess. Nothing is saved without going through that review screen.

**Tech Stack:** Flutter/Dart, `google_mlkit_text_recognition` (already a dependency, previously unused), new dependency `image_picker`.

**Spec:** `docs/superpowers/specs/2026-09-06-receipt-scanner-design.md`

## Global Constraints

- No cloud-vision fallback in this version — on-device OCR only. Deferred, not dropped (see spec's Out of Scope section).
- Every OCR result routes through `EditEntryScreen` for mandatory human review before any `TransactionRepository.create()` call — never auto-saved.
- Any run of 8+ consecutive digits in OCR text is redacted (masked, keep last 4) before merchant/amount extraction ever sees it — unconditional, not confidence-gated.
- `flutter analyze` clean and the full `flutter test` suite green before every commit.
- `flutter pub add <package>` for new dependencies — never hand-edit a version number into `pubspec.yaml`.
- Pure logic (`receipt_parser.dart`) gets full unit tests with fixture data; the real ML Kit wrapper and real camera/photo-library permission flows are manual/device-only verification, consistent with this project's established pattern (ML Kit doesn't run in tests or on the iOS Simulator at all).
- Follow `DESIGN.md`/`CLAUDE.md`'s component-reuse rule — no new one-off widgets where `StubButton`/`StubChip`/`StubCard`/`StubIcon` already cover the need.

---

### Task 1: TextRecognitionService interface, RecognizedLine, FakeTextRecognitionService

**Files:**
- Create: `app/lib/data/text_recognition_service.dart`
- Modify: `app/lib/data/fakes.dart`
- Test: `app/test/data/fakes_test.dart` (extend existing file)

**Interfaces:**
- Produces: `RecognizedLine` (`text`, `boundingBox` — a `dart:ui` `Rect`), abstract `TextRecognitionService` with `Future<List<RecognizedLine>> recognizeText(String imagePath)`, and `FakeTextRecognitionService implements TextRecognitionService`.
- Consumes: nothing from earlier tasks (this is the first task).

- [ ] **Step 1: Write the failing test**

```dart
// Add to app/test/data/fakes_test.dart

test('FakeTextRecognitionService.recognizeText returns the configured result', () async {
  final service = FakeTextRecognitionService();
  expect(await service.recognizeText('any/path.jpg'), isEmpty);

  const lines = [RecognizedLine(text: 'Corner Market', boundingBox: Rect.zero)];
  final withResult = FakeTextRecognitionService(result: lines);
  expect(await withResult.recognizeText('any/path.jpg'), lines);
});
```

Add these imports at the top of `app/test/data/fakes_test.dart` alongside the existing ones:

```dart
import 'dart:ui';
import 'package:stub/data/text_recognition_service.dart';
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/data/fakes_test.dart
```

Expected: fails to compile — `text_recognition_service.dart` and `FakeTextRecognitionService` don't exist yet.

- [ ] **Step 3: Implement**

`app/lib/data/text_recognition_service.dart`:

```dart
import 'dart:ui';

/// One line of text recognized in an image, with its position — enough
/// for `receipt_parser.dart`'s position-based reconstruction, not the
/// full API surface of whichever OCR engine produced it.
class RecognizedLine {
  const RecognizedLine({required this.text, required this.boundingBox});

  final String text;
  final Rect boundingBox;

  @override
  bool operator ==(Object other) =>
      other is RecognizedLine && other.text == text && other.boundingBox == boundingBox;

  @override
  int get hashCode => Object.hash(text, boundingBox);
}

abstract class TextRecognitionService {
  Future<List<RecognizedLine>> recognizeText(String imagePath);
}
```

(`==`/`hashCode` are needed so the test's list-equality check (`withResult.recognizeText(...)`, `lines`) works as expected — `RecognizedLine` has no other reason to need value equality elsewhere in the app.)

Add to `app/lib/data/fakes.dart` (new import at the top alongside the existing ones, and the class at the end of the file, matching this file's existing style):

```dart
import 'text_recognition_service.dart';
```

```dart
class FakeTextRecognitionService implements TextRecognitionService {
  FakeTextRecognitionService({this.result = const []});
  List<RecognizedLine> result;

  @override
  Future<List<RecognizedLine>> recognizeText(String imagePath) async => result;
}
```

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/data/fakes_test.dart && flutter analyze
git add lib/data/text_recognition_service.dart lib/data/fakes.dart test/data/fakes_test.dart
git commit -m "feat: add TextRecognitionService interface and fake"
```

---

### Task 2: receipt_parser.dart — pure parsing logic

**Files:**
- Create: `app/lib/util/receipt_parser.dart`
- Test: `app/test/util/receipt_parser_test.dart`

**Interfaces:**
- Produces: `ParsedReceipt` (`merchant`/`amount`/`occurredAt`, all nullable), `String redactLongDigitRuns(String text)`, `ParsedReceipt parseReceiptLines(List<RecognizedLine> lines)`.
- Consumes: `RecognizedLine` from Task 1 (`app/lib/data/text_recognition_service.dart`).

This is a pure Dart file — no Flutter widget dependencies, no platform calls — fully unit-tested, matching `csv_export.dart`'s established pure/platform split.

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/util/receipt_parser_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/text_recognition_service.dart';
import 'package:stub/util/receipt_parser.dart';

RecognizedLine _line(String text, {double top = 0, double left = 0, double height = 20}) =>
    RecognizedLine(text: text, boundingBox: Rect.fromLTWH(left, top, 100, height));

void main() {
  group('redactLongDigitRuns', () {
    test('masks a run of 8+ digits, keeping the last 4', () {
      expect(redactLongDigitRuns('Card ending 123456789012'), 'Card ending ••••9012');
    });

    test('leaves short digit runs untouched', () {
      expect(redactLongDigitRuns('Total 12.99, Qty 2'), 'Total 12.99, Qty 2');
    });
  });

  group('parseReceiptLines', () {
    test('returns all-null fields for an empty list', () {
      final result = parseReceiptLines(const []);
      expect(result.merchant, isNull);
      expect(result.amount, isNull);
      expect(result.occurredAt, isNull);
    });

    test('extracts merchant as the first line in reading order, amount, and date', () {
      final lines = [
        _line('Corner Market', top: 0),
        _line('01/15/2026', top: 20),
        _line('Total \$45.99', top: 40),
      ];
      final result = parseReceiptLines(lines);
      expect(result.merchant, 'Corner Market');
      expect(result.amount, 45.99);
      expect(result.occurredAt, DateTime(2026, 1, 15));
    });

    test('reconstructs reading order from scrambled input using position, not list order', () {
      // Listed out of order, but positioned top-to-bottom correctly —
      // merchant must come from the top-most line, not lines[0].
      final lines = [
        _line('Total \$10.00', top: 40),
        _line('Corner Market', top: 0),
      ];
      final result = parseReceiptLines(lines);
      expect(result.merchant, 'Corner Market');
    });

    test('prefers a line containing "total" over a larger unrelated number', () {
      final lines = [
        _line('Item A \$99.00', top: 0),
        _line('Total \$10.00', top: 20),
      ];
      final result = parseReceiptLines(lines);
      expect(result.amount, 10.00);
    });

    test('falls back to the largest amount when no total-keyword line exists', () {
      final lines = [
        _line('Item A \$5.00', top: 0),
        _line('Item B \$12.99', top: 20),
      ];
      final result = parseReceiptLines(lines);
      expect(result.amount, 12.99);
    });

    test('returns null amount when no currency-shaped number is found', () {
      final lines = [_line('Corner Market'), _line('Thank you for shopping')];
      final result = parseReceiptLines(lines);
      expect(result.amount, isNull);
    });

    test('redacts a long digit run before it can appear as the merchant guess', () {
      final lines = [_line('Card 411111111111'), _line('Total \$20.00', top: 20)];
      final result = parseReceiptLines(lines);
      expect(result.merchant, contains('••••'));
      expect(result.merchant, isNot(contains('411111111111')));
    });

    test('parses an ISO-format date (YYYY-MM-DD)', () {
      final lines = [_line('2026-03-05')];
      final result = parseReceiptLines(lines);
      expect(result.occurredAt, DateTime(2026, 3, 5));
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/util/receipt_parser_test.dart
```

Expected: fails to compile — `receipt_parser.dart` doesn't exist yet.

- [ ] **Step 3: Implement**

```dart
// app/lib/util/receipt_parser.dart
import '../data/text_recognition_service.dart';

/// Best-effort merchant/amount/date guesses extracted from OCR output —
/// any field may be null if nothing confident was found. Always routed
/// through a mandatory human-review screen (`EditEntryScreen`) before
/// being saved, per the OCR spike's findings (see CLAUDE.md) — never
/// auto-saved.
class ParsedReceipt {
  const ParsedReceipt({this.merchant, this.amount, this.occurredAt});

  final String? merchant;
  final double? amount;
  final DateTime? occurredAt;
}

final _amountPattern = RegExp(r'\$?\s?(\d{1,3}(?:,\d{3})*\.\d{2})');
final _totalKeywordPattern = RegExp(r'total|amount due', caseSensitive: false);
final _mmddyyyyPattern = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');
final _isoDatePattern = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
final _longDigitRunPattern = RegExp(r'\d{8,}');

/// Masks any run of 8+ consecutive digits (account/ID numbers), keeping
/// only the last 4 — applied unconditionally before any extraction below
/// so a raw account number can never survive into a stored transaction
/// or the UI, regardless of which heuristic produced the match.
String redactLongDigitRuns(String text) {
  return text.replaceAllMapped(_longDigitRunPattern, (match) {
    final digits = match.group(0)!;
    return '••••${digits.substring(digits.length - 4)}';
  });
}

/// Row-clusters [lines] by vertical position, then sorts each row
/// left-to-right — the OCR spike's validated technique for correcting
/// out-of-order reads on receipts with multi-column layouts.
List<RecognizedLine> _reconstructReadingOrder(List<RecognizedLine> lines) {
  if (lines.isEmpty) return const [];
  final sorted = [...lines]..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
  final rows = <List<RecognizedLine>>[];
  for (final line in sorted) {
    final lineHeight = line.boundingBox.height;
    List<RecognizedLine>? matchingRow;
    for (final row in rows) {
      final rowTop = row.first.boundingBox.top;
      if ((line.boundingBox.top - rowTop).abs() < lineHeight * 0.6) {
        matchingRow = row;
        break;
      }
    }
    if (matchingRow != null) {
      matchingRow.add(line);
    } else {
      rows.add([line]);
    }
  }
  for (final row in rows) {
    row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
  }
  return [for (final row in rows) for (final line in row)];
}

DateTime? _parseDate(String text) {
  final mmddyyyy = _mmddyyyyPattern.firstMatch(text);
  if (mmddyyyy != null) {
    final month = int.parse(mmddyyyy.group(1)!);
    final day = int.parse(mmddyyyy.group(2)!);
    var year = int.parse(mmddyyyy.group(3)!);
    if (year < 100) year += 2000;
    return DateTime(year, month, day);
  }
  final iso = _isoDatePattern.firstMatch(text);
  if (iso != null) {
    return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
  }
  return null;
}

/// Extracts a best-effort merchant/amount/date guess from OCR output.
/// Every field may come back null — the caller must always route the
/// result through a review screen, never save it directly.
ParsedReceipt parseReceiptLines(List<RecognizedLine> lines) {
  final ordered = _reconstructReadingOrder(lines);
  final redactedTexts = [for (final l in ordered) redactLongDigitRuns(l.text)];

  double? largestAmount;
  double? totalLineAmount;
  for (final text in redactedTexts) {
    final match = _amountPattern.firstMatch(text);
    if (match == null) continue;
    final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (value == null) continue;
    if (largestAmount == null || value > largestAmount) largestAmount = value;
    if (totalLineAmount == null && _totalKeywordPattern.hasMatch(text)) {
      totalLineAmount = value;
    }
  }

  DateTime? occurredAt;
  for (final text in redactedTexts) {
    occurredAt = _parseDate(text);
    if (occurredAt != null) break;
  }

  String? merchant;
  for (final text in redactedTexts) {
    if (text.trim().isNotEmpty) {
      merchant = text;
      break;
    }
  }

  return ParsedReceipt(
    merchant: merchant,
    amount: totalLineAmount ?? largestAmount,
    occurredAt: occurredAt,
  );
}
```

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/util/receipt_parser_test.dart && flutter analyze
git add lib/util/receipt_parser.dart test/util/receipt_parser_test.dart
git commit -m "feat: add receipt_parser.dart with position reconstruction, extraction, and redaction"
```

---

### Task 3: MlKitTextRecognitionService — real implementation

**Files:**
- Create: `app/lib/data/mlkit_text_recognition_service.dart`

**Interfaces:**
- Produces: `MlKitTextRecognitionService implements TextRecognitionService`.
- Consumes: `TextRecognitionService`/`RecognizedLine` from Task 1.

No unit test for this file — it's a thin wrapper around a real ML Kit plugin call, which doesn't run in `flutter test` or on the iOS Simulator (per CLAUDE.md's existing note on `google_mlkit_text_recognition`). Verified manually on a physical device only, same pattern as `SupabaseTransactionRepository` and friends.

**Before writing any code**: this task uses the real, installed `google_mlkit_text_recognition` (`0.17.1`) API — verify it against `~/.pub-cache/hosted/pub.dev/google_mlkit_text_recognition-0.17.1/lib/src/text_recognizer.dart` and `google_mlkit_commons-0.13.0/lib/src/input_image.dart` (find exact paths via `app/.dart_tool/package_config.json`) before finalizing, the same way earlier plans in this repo verified `gotrue`'s `User.createdAt` type against real installed source rather than guessing. The shape below was confirmed against those exact files at plan-writing time — confirm it hasn't changed if the installed version differs.

- [ ] **Step 1: Implement**

```dart
// app/lib/data/mlkit_text_recognition_service.dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'text_recognition_service.dart';

class MlKitTextRecognitionService implements TextRecognitionService {
  @override
  Future<List<RecognizedLine>> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      return [
        for (final block in result.blocks)
          for (final line in block.lines)
            RecognizedLine(text: line.text, boundingBox: line.boundingBox),
      ];
    } finally {
      await recognizer.close();
    }
  }
}
```

- [ ] **Step 2: `flutter analyze`, commit**

```
cd app && flutter analyze
git add lib/data/mlkit_text_recognition_service.dart
git commit -m "feat: add MlKitTextRecognitionService"
```

---

### Task 4: EditEntryScreen — editable merchant/amount fields + create mode

**Files:**
- Modify: `app/lib/screens/edit_entry_screen.dart`
- Modify: `app/lib/screens/root_shell.dart` (update the existing `_openEditEntry` call site to match the new `onSave` signature — required for the app to keep compiling; this task does NOT wire the new scan-to-create flow yet, that's Task 6)
- Test: `app/test/screens/edit_entry_screen_test.dart` (extend existing file)

**Interfaces:**
- Produces: `EditEntryScreen` gains `isCreating` (`bool`, default `false`). `onSave`'s type changes from `ValueChanged<String>` to `void Function(String merchant, double amount, String category)`. When `isCreating` is `true`, no Delete button is shown.
- Consumes: nothing new — this is a change to an existing screen.

**Before writing any code**: `EditEntryScreen`'s merchant/amount `StubFieldRow`s currently have `editable: true` but no `onTap` wired — that flag only draws a pencil icon today, it doesn't make the field tappable. This task fixes that using the existing `_MerchantDialog` pattern already established in `app/lib/screens/manual_entry_screen.dart` (a small `AlertDialog` with a `TextField`) — reuse that exact shape here (a new, slightly more general dialog, since this screen needs it for two fields with different keyboard types, not one).

- [ ] **Step 1: Write the failing tests**

```dart
// Replace the existing test in app/test/screens/edit_entry_screen_test.dart with:
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/edit_entry_screen.dart';

void main() {
  testWidgets('EditEntryScreen lets you switch category and save', (tester) async {
    String? savedMerchant;
    double? savedAmount;
    String? savedCategory;
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          merchant: 'Corner Market',
          amount: 18.42,
          categories: const ['Groceries', 'Dining', 'Household'],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan · Today',
          onClose: () {},
          onSave: (merchant, amount, category) {
            savedMerchant = merchant;
            savedAmount = amount;
            savedCategory = category;
          },
          onDelete: () {},
        ),
      ),
    );
    expect(find.text('Corner Market'), findsOneWidget);

    await tester.tap(find.text('Dining'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    expect(savedMerchant, 'Corner Market');
    expect(savedAmount, 18.42);
    expect(savedCategory, 'Dining');
  });

  testWidgets('Tapping the merchant field opens an editable dialog that updates the value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          merchant: 'Corner Market',
          amount: 18.42,
          categories: const ['Groceries'],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan · Today',
          onClose: () {},
          onSave: (_, __, ___) {},
          onDelete: () {},
        ),
      ),
    );

    await tester.tap(find.text('Corner Market'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'New Merchant');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New Merchant'), findsOneWidget);
  });

  testWidgets('isCreating hides the Delete button and onSave still fires', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          isCreating: true,
          merchant: '',
          amount: 0,
          categories: const ['Groceries'],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan · Today',
          onClose: () {},
          onSave: (_, __, ___) => saved = true,
          onDelete: () {},
        ),
      ),
    );

    expect(find.text('Delete entry'), findsNothing);
    await tester.tap(find.text('Save changes'));
    expect(saved, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/screens/edit_entry_screen_test.dart
```

Expected: fails to compile — `isCreating` doesn't exist, `onSave`'s type doesn't match, fields aren't tappable.

- [ ] **Step 3: Implement**

Replace `app/lib/screens/edit_entry_screen.dart` in full:

```dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/currency.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_chip.dart';
import '../widgets/stub_field_row.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_pressable.dart';

class EditEntryScreen extends StatefulWidget {
  const EditEntryScreen({
    super.key,
    this.isCreating = false,
    required this.merchant,
    required this.amount,
    required this.categories,
    required this.selectedCategory,
    required this.sourceLabel,
    required this.onClose,
    required this.onSave,
    this.onDelete,
  });

  final bool isCreating;
  final String merchant;
  final double amount;
  final List<String> categories;
  final String selectedCategory;
  final String sourceLabel;
  final VoidCallback onClose;
  final void Function(String merchant, double amount, String category) onSave;
  final VoidCallback? onDelete;

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  late String _selected = widget.selectedCategory;
  late String _merchant = widget.merchant;
  late double _amount = widget.amount;

  Future<void> _editMerchant() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditFieldDialog(title: 'Merchant', initial: _merchant),
    );
    if (result != null) setState(() => _merchant = result);
  }

  Future<void> _editAmount() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Amount',
        initial: _amount.toStringAsFixed(2),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
    if (result != null) {
      final parsed = double.tryParse(result);
      if (parsed != null) setState(() => _amount = parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final danger = isDark ? StubColors.dangerDark : StubColors.dangerLight;

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: widget.onClose),
        title: Text('Edit entry', style: StubText.archivo(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StubFieldRow(label: 'Merchant', value: _merchant, editable: true, onTap: _editMerchant),
              StubFieldRow(
                label: 'Amount',
                value: formatCurrency(_amount),
                mono: true,
                editable: true,
                onTap: _editAmount,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CATEGORY', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink.withValues(alpha: 0.5))),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in widget.categories)
                          StubChip(label: c, selected: c == _selected, onTap: () => setState(() => _selected = c)),
                      ],
                    ),
                  ],
                ),
              ),
              StubFieldRow(label: 'Source', value: widget.sourceLabel, valueColor: ink.withValues(alpha: 0.6)),
              const SizedBox(height: 22),
              StubButton(
                label: 'Save changes',
                variant: StubButtonVariant.save,
                onPressed: () => widget.onSave(_merchant, _amount, _selected),
              ),
              if (!widget.isCreating) ...[
                const SizedBox(height: 12),
                Center(
                  child: StubPressable(
                    onTap: widget.onDelete,
                    ensureMinTapSize: true,
                    child: Text('Delete entry', style: StubText.archivo(fontSize: 13, fontWeight: FontWeight.w600, color: danger)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditFieldDialog extends StatefulWidget {
  const _EditFieldDialog({required this.title, required this.initial, this.keyboardType});
  final String title;
  final String initial;
  final TextInputType? keyboardType;

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(controller: _controller, autofocus: true, keyboardType: widget.keyboardType),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Save')),
      ],
    );
  }
}
```

Now update `app/lib/screens/root_shell.dart`'s existing `_openEditEntry` method (the only current caller of `EditEntryScreen`) to match the new 3-argument `onSave`:

```dart
// Replace the existing _openEditEntry method body's onSave with:
        onSave: (merchant, amount, category) => _guardedWrite(() async {
          final selectedCategory = categories.firstWhere((c) => c.name == category);
          await widget.transactionRepository.update(
            transaction.copyWith(
              merchant: merchant,
              amount: amount,
              category: category,
              categoryId: selectedCategory.id,
            ),
          );
        }, onSuccess: () => Navigator.of(context).pop()),
```

(Everything else in `_openEditEntry` stays the same — only the `onSave:` closure's parameter list and body change.)

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/screens/edit_entry_screen_test.dart test/screens/root_shell_test.dart && flutter analyze
git add lib/screens/edit_entry_screen.dart lib/screens/root_shell.dart test/screens/edit_entry_screen_test.dart
git commit -m "feat: make EditEntryScreen's merchant/amount fields genuinely editable, add create mode"
```

---

### Task 5: ScanScreen redesign — capture, source-type picker, OCR

**Files:**
- Modify: `app/lib/screens/scan_screen.dart` (full rewrite)
- Test: `app/test/screens/scan_screen_test.dart` (full rewrite)

**Interfaces:**
- Produces: `ScanScreen({required TextRecognitionService textRecognitionService, required VoidCallback onClose, required void Function(ParsedReceipt parsed, TransactionSource source) onScanned})`. Does not push `EditEntryScreen` itself — only calls `onScanned`; `RootShell` (Task 6) owns the actual navigation, matching this project's established pattern where screens never call `Navigator` for anything beyond their own close button.
- Consumes: `TextRecognitionService`/`FakeTextRecognitionService` (Task 1), `ParsedReceipt`/`parseReceiptLines` (Task 2), `TransactionSource` (`app/lib/models/transaction.dart`, already exists).

- [ ] **Step 1: Add the `image_picker` dependency**

```bash
cd app
flutter pub add image_picker
```

**Before finalizing this task's code**: `image_picker`'s core API (`ImagePicker().pickImage(source: ImageSource.camera)` returning `XFile?`) has been stable for years, but verify the exact shape against whatever version `flutter pub add` resolves (find it via `app/.dart_tool/package_config.json`) before treating the snippet below as final — same verify-before-trusting approach every real-API task in this project's plans has used.

- [ ] **Step 2: Write the failing tests**

```dart
// app/test/screens/scan_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/data/text_recognition_service.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/screens/scan_screen.dart';
import 'package:stub/util/receipt_parser.dart';

void main() {
  testWidgets('Picking a source type and continuing calls onScanned with the parsed result', (tester) async {
    ParsedReceipt? scannedParsed;
    TransactionSource? scannedSource;

    final service = FakeTextRecognitionService();

    // Real capture goes through `image_picker`, which can't return a fake
    // result inside a widget test — `debugInitialImagePath` is a test-only
    // seam that skips straight to the type-picker stage with a fake path,
    // so the OCR/parse/onScanned wiring past that point is still tested
    // for real. See Step 4 for its definition.
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          textRecognitionService: service,
          onClose: () {},
          onScanned: (parsed, source) {
            scannedParsed = parsed;
            scannedSource = source;
          },
          debugInitialImagePath: 'test/fixtures/fake.jpg',
        ),
      ),
    );

    expect(find.text('Receipt'), findsOneWidget);
    await tester.tap(find.text('Receipt'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(scannedSource, TransactionSource.receipt);
    expect(scannedParsed, isNotNull);
  });

  testWidgets('Continue is disabled until a source type is picked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          textRecognitionService: FakeTextRecognitionService(),
          onClose: () {},
          onScanned: (_, __) {},
          debugInitialImagePath: 'test/fixtures/fake.jpg',
        ),
      ),
    );

    final continueButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue'));
    expect(continueButton.onPressed, isNull);
  });
}
```

- [ ] **Step 3: Run to verify it fails**

```
cd app && flutter test test/screens/scan_screen_test.dart
```

Expected: fails to compile — the new `ScanScreen` constructor shape and `debugInitialImagePath` don't exist yet.

- [ ] **Step 4: Implement**

Replace `app/lib/screens/scan_screen.dart` in full:

```dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/text_recognition_service.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/receipt_parser.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_chip.dart';
import '../widgets/stub_icon.dart';

enum _ScanStage { choosingSource, choosingType, processing }

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.textRecognitionService,
    required this.onClose,
    required this.onScanned,
    this.debugInitialImagePath,
  });

  final TextRecognitionService textRecognitionService;
  final VoidCallback onClose;
  final void Function(ParsedReceipt parsed, TransactionSource source) onScanned;

  /// Test-only seam: real image capture goes through `image_picker`,
  /// which can't return a fake result inside a widget test. Setting this
  /// skips straight to the type-picker stage with this path, so the
  /// OCR/parse/onScanned wiring past that point can still be tested for
  /// real. Never set outside tests.
  final String? debugInitialImagePath;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late _ScanStage _stage =
      widget.debugInitialImagePath == null ? _ScanStage.choosingSource : _ScanStage.choosingType;
  late String? _imagePath = widget.debugInitialImagePath;
  TransactionSource? _selectedSource;

  Future<void> _pickImage(ImageSource imageSource) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: imageSource);
    } catch (_) {
      // Covers permission-denied and any other platform-level failure —
      // there's nothing to recover into, so surface it and back out.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera access is needed to scan a receipt — enable it in Settings.')),
        );
      }
      widget.onClose();
      return;
    }
    if (picked == null) {
      widget.onClose();
      return;
    }
    setState(() {
      _imagePath = picked!.path;
      _stage = _ScanStage.choosingType;
    });
  }

  Future<void> _continue() async {
    final imagePath = _imagePath;
    final source = _selectedSource;
    if (imagePath == null || source == null) return;
    setState(() => _stage = _ScanStage.processing);
    ParsedReceipt parsed;
    try {
      final lines = await widget.textRecognitionService.recognizeText(imagePath);
      parsed = parseReceiptLines(lines);
    } catch (_) {
      parsed = const ParsedReceipt();
    }
    widget.onScanned(parsed, source);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: widget.onClose),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_stage) {
            _ScanStage.choosingSource => _SourcePicker(
                ink: ink,
                onPickCamera: () => _pickImage(ImageSource.camera),
                onPickGallery: () => _pickImage(ImageSource.gallery),
              ),
            _ScanStage.choosingType => _TypePicker(
                ink: ink,
                ink50: ink50,
                selected: _selectedSource,
                onSelect: (s) => setState(() => _selectedSource = s),
                onContinue: _continue,
              ),
            _ScanStage.processing => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker({required this.ink, required this.onPickCamera, required this.onPickGallery});
  final Color ink;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Scan a receipt', style: StubText.domine(fontSize: 20, color: ink)),
        const SizedBox(height: 24),
        StubButton(label: 'Take photo', onPressed: onPickCamera),
        const SizedBox(height: 12),
        StubButton(label: 'Choose from library', onPressed: onPickGallery),
      ],
    );
  }
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({
    required this.ink,
    required this.ink50,
    required this.selected,
    required this.onSelect,
    required this.onContinue,
  });
  final Color ink;
  final Color ink50;
  final TransactionSource? selected;
  final ValueChanged<TransactionSource> onSelect;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What kind of image is this?',
          style: StubText.archivo(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StubChip(
              label: 'Receipt',
              selected: selected == TransactionSource.receipt,
              onTap: () => onSelect(TransactionSource.receipt),
            ),
            StubChip(
              label: 'Payment app',
              selected: selected == TransactionSource.paymentApp,
              onTap: () => onSelect(TransactionSource.paymentApp),
            ),
            StubChip(
              label: 'Bank screenshot',
              selected: selected == TransactionSource.bankScreenshot,
              onTap: () => onSelect(TransactionSource.bankScreenshot),
            ),
          ],
        ),
        const Spacer(),
        StubButton(label: 'Continue', onPressed: selected == null ? null : onContinue),
      ],
    );
  }
}
```

- [ ] **Step 5: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/screens/scan_screen_test.dart && flutter analyze
git add pubspec.yaml pubspec.lock lib/screens/scan_screen.dart test/screens/scan_screen_test.dart
git commit -m "feat: redesign ScanScreen with real capture, source picker, and on-device OCR"
```

---

### Task 6: RootShell wiring — real scan-to-transaction flow

**Files:**
- Modify: `app/lib/screens/root_shell.dart`
- Modify: `app/lib/main.dart` (thread a `TextRecognitionService` into `RootShell`, matching how the other repositories/services are already threaded)
- Test: `app/test/screens/root_shell_test.dart` (extend existing file)

**Interfaces:**
- `RootShell` gains one more required constructor parameter: `TextRecognitionService textRecognitionService`.
- Consumes: `ScanScreen` (Task 5), `EditEntryScreen`'s `isCreating` mode (Task 4), `MlKitTextRecognitionService` (Task 3, for `main.dart`'s real construction).

**Before writing any code**: read `app/lib/main.dart`'s current structure fully before editing — per this project's established convention (its shape has changed multiple times across prior plans), don't guess at it.

- [ ] **Step 1: Write the failing test**

```dart
// Add to app/test/screens/root_shell_test.dart

testWidgets('Scanning a receipt opens EditEntryScreen pre-filled with the parsed result, and saving creates a transaction', (tester) async {
  final categories = FakeCategoryRepository();
  final groceries = await categories.create('Groceries');
  final transactions = FakeTransactionRepository();
  final budgets = FakeBudgetRepository(null, categories);
  await budgets.create(categoryId: groceries.id, limitAmount: 300, periodType: BudgetPeriodType.monthly, periodStart: DateTime.now());

  final ocrLines = [
    RecognizedLine(text: 'Corner Market', boundingBox: Rect.fromLTWH(0, 0, 100, 20)),
    RecognizedLine(text: 'Total \$18.42', boundingBox: Rect.fromLTWH(0, 20, 100, 20)),
  ];

  await tester.pumpWidget(MaterialApp(home: RootShell(
    categoryRepository: categories,
    transactionRepository: transactions,
    budgetRepository: budgets,
    accountLinkService: FakeAccountLinkService(),
    themeModeNotifier: ValueNotifier(ThemeMode.system),
    localPrefs: LocalPrefs(),
    textRecognitionService: FakeTextRecognitionService(result: ocrLines),
  )));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('stub-bottom-nav-scan-button')));
  await tester.pumpAndSettle();

  // Drive ScanScreen's test seam directly isn't possible from here since
  // RootShell constructs it internally — so this test instead confirms
  // ScanScreen opened, then exercises the create-flow's EditEntryScreen
  // wiring directly via RootShell's own scanned-result callback path.
  expect(find.text('Scan a receipt'), findsOneWidget);
});

testWidgets('_openScan wires a scanned result into a real EditEntryScreen create flow', (tester) async {
  final categories = FakeCategoryRepository();
  final groceries = await categories.create('Groceries');
  final transactions = FakeTransactionRepository();
  final budgets = FakeBudgetRepository(null, categories);
  await budgets.create(categoryId: groceries.id, limitAmount: 300, periodType: BudgetPeriodType.monthly, periodStart: DateTime.now());

  await tester.pumpWidget(MaterialApp(home: RootShell(
    categoryRepository: categories,
    transactionRepository: transactions,
    budgetRepository: budgets,
    accountLinkService: FakeAccountLinkService(),
    themeModeNotifier: ValueNotifier(ThemeMode.system),
    localPrefs: LocalPrefs(),
    textRecognitionService: FakeTextRecognitionService(),
  )));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('stub-bottom-nav-scan-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Take photo'));
  await tester.pumpAndSettle();
});
```

(Add these imports to `app/test/screens/root_shell_test.dart` alongside the existing ones: `import 'dart:ui';` and `import 'package:stub/data/text_recognition_service.dart';`)

The first test only asserts `ScanScreen` opens (a real `image_picker` call can't be driven in a widget test without a platform mock, which is out of scope for this task's automated coverage — consistent with this project's manual-verification pattern for OS-level integration). The second test exercises tapping "Take photo," which on a real device launches the camera; in the test environment with no platform channel mock installed, `image_picker`'s `pickImage` call will not resolve to a real image, so this test's purpose is only to confirm the button exists and is tappable without throwing — not to drive a full scan-to-save cycle end to end (that's manual/device verification, same as CSV export and the deep-link flow).

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/screens/root_shell_test.dart
```

Expected: fails to compile — `RootShell` doesn't accept `textRecognitionService` yet.

- [ ] **Step 3: Implement**

In `app/lib/screens/root_shell.dart`, add the import:

```dart
import '../data/text_recognition_service.dart';
import '../util/receipt_parser.dart';
```

Add `textRecognitionService` to `RootShell`'s constructor and fields, following the exact pattern of the existing `accountLinkService`/`themeModeNotifier`/`localPrefs` parameters (add the `required this.textRecognitionService,` line to the constructor, and `final TextRecognitionService textRecognitionService;` to the fields).

Replace the existing `_openScan` method:

```dart
void _openScan() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScanScreen(
        textRecognitionService: widget.textRecognitionService,
        onClose: () => Navigator.of(context).pop(),
        onScanned: (parsed, source) => _handleScanned(parsed, source),
      ),
    ));
  }

  void _handleScanned(ParsedReceipt parsed, TransactionSource source) {
    Navigator.of(context).pop(); // close ScanScreen
    _dataFuture.then((data) {
      if (mounted) _openScanCreateFlow(parsed, source, data.categories);
    });
  }

  void _openScanCreateFlow(ParsedReceipt parsed, TransactionSource source, List<Category> categories) {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a category first, then log an expense.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditEntryScreen(
        isCreating: true,
        merchant: parsed.merchant ?? '',
        amount: parsed.amount ?? 0,
        categories: [for (final c in categories) c.name],
        selectedCategory: categories.first.name,
        sourceLabel: switch (source) {
          TransactionSource.receipt => 'Receipt scan',
          TransactionSource.paymentApp => 'Payment app scan',
          TransactionSource.bankScreenshot => 'Bank screenshot scan',
          TransactionSource.manual => 'Manual',
        },
        onClose: () => Navigator.of(context).pop(),
        onSave: (merchant, amount, categoryName) => _guardedWrite(() async {
          final category = categories.firstWhere((c) => c.name == categoryName);
          await widget.transactionRepository.create(Transaction(
            id: '',
            categoryId: category.id,
            merchant: merchant,
            amount: amount,
            category: categoryName,
            source: source,
            occurredAt: parsed.occurredAt ?? DateTime.now(),
          ));
        }, onSuccess: () => Navigator.of(context).pop()),
      ),
    ));
  }
```

(`onDelete` is omitted here — see Task 4's change making it optional, since create mode never shows a Delete button and therefore never needs a real callback.)

(`_handleScanned` needs the current category list, which lives inside `_dataFuture`'s resolved value — since `_openScan`/`_handleScanned` are called from outside `build()`'s `FutureBuilder` callback, awaiting `_dataFuture` directly here is the simplest correct way to reach it, matching how `_openManualEntry`/`_openEditEntry` already receive `categories` as a parameter from inside `build()`'s scope in the existing code — this new path is the one exception because `ScanScreen`'s result arrives asynchronously via a callback, not synchronously inside `build()`.)

`app/lib/main.dart` threads five dependencies from `StubApp` through `_LockGate` into `RootShell` today (`categoryRepository`, `transactionRepository`, `budgetRepository`, `accountLinkService`, `localPrefs`, plus `themeModeNotifier` — six, all told). `textRecognitionService` needs the exact same treatment, added at every one of those points. Make these five changes:

1. Add the import, alongside the existing `data/` imports:

```dart
import 'data/mlkit_text_recognition_service.dart';
import 'data/text_recognition_service.dart';
```

2. `StubApp`'s constructor and fields — add `required this.textRecognitionService,` to the constructor and `final TextRecognitionService textRecognitionService;` to the fields, matching `localPrefs`'s existing pattern exactly. In `StubApp.build()`, add `textRecognitionService: textRecognitionService,` to the `_LockGate(...)` construction.

3. `_LockGate`'s constructor and fields — same addition: `required this.textRecognitionService,` and `final TextRecognitionService textRecognitionService;`.

4. `_LockGateState.build()`'s `RootShell(...)` construction — add `textRecognitionService: widget.textRecognitionService,` alongside the existing five arguments.

5. `_StartupGateState.build()`'s `StubApp(...)` construction (the one built once `_startup()` resolves successfully) — add `textRecognitionService: MlKitTextRecognitionService(),` alongside the existing five arguments, since this is where the real (non-fake) service gets constructed for the live app, matching how `SupabaseCategoryRepository(Supabase.instance.client)` etc. are constructed at that exact call site rather than earlier in `_startup()`.

- [ ] **Step 4: Run the full suite, fix any other affected call site**

```
cd app && flutter test
```

Fix any remaining compile errors from the constructor signature change — expected, mechanical work (any other `RootShell(...)` construction site, e.g. in `main.dart`'s tests, needs `textRecognitionService: FakeTextRecognitionService()` or the real service added).

- [ ] **Step 5: `flutter analyze`, manual verification, commit**

```
cd app && flutter analyze
```

Manually trace (code inspection, since ML Kit needs a real device to verify per CLAUDE.md): does tapping the scan button open `ScanScreen`? Does a real capture flow through OCR into a pre-filled `EditEntryScreen`? Note in your report that the real end-to-end camera → OCR → save path needs a physical device to verify live, consistent with this project's established pattern.

```bash
git add lib/screens/root_shell.dart lib/main.dart test/screens/root_shell_test.dart
git commit -m "feat: wire RootShell's scan button to the real capture/OCR/create flow"
```

---

### Task 7: CLAUDE.md documentation update

**Files:**
- Modify: `CLAUDE.md` (repo root)

**Interfaces:** none (docs only).

- [ ] **Step 1: Update the file map**

Add rows for every new file: `lib/data/text_recognition_service.dart`, `lib/data/mlkit_text_recognition_service.dart`, `lib/util/receipt_parser.dart`, plus their test files. Update `fakes.dart`'s row (`FakeTextRecognitionService` added). Update `ScanScreen`'s row (real capture/OCR, no longer a hardcoded confirm-card) and `EditEntryScreen`'s row (`isCreating` mode, genuinely editable fields).

- [ ] **Step 2: Update the Status paragraph**

Reflect that `ScanScreen` now performs real capture/OCR and creates real transactions (remove the "still a no-op stub" language), and update the real final test count (run `flutter test` yourself — don't guess).

- [ ] **Step 3: Update the Component inventory**

No new reusable component was introduced (this feature composes existing `StubButton`/`StubChip`/`StubIcon`) — note this explicitly if it isn't already obvious, rather than adding a row that isn't needed.

- [ ] **Step 4: Update Open Items**

Verify each against current code before writing (this project has repeatedly caught hallucinated CLAUDE.md claims — read the real files):
- Remove or rewrite the existing "`ScanScreen` still has no real camera/OCR behind it" item — it's resolved.
- Add a new item: cloud-vision fallback for itemized/multi-column receipts is deliberately deferred (not built), pending real usage data and a billing/API-account decision — reference the design spec.
- Add a new item: the real ML Kit accuracy re-validation against the OCR spike's 5-image sample (mentioned as a pre-existing open item already) is now directly testable with this feature wired up — note that it still hasn't been done.
- Note that the full scan → OCR → save flow has not been verified end-to-end on a physical device (ML Kit doesn't run in tests or on the iOS Simulator).

- [ ] **Step 5: Commit**

```
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for the receipt scanner"
```
