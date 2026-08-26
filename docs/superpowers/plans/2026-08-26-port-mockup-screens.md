# Port Mockup Screens to Real Flutter UI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the temporary `_ThemeCheckScreen` in `main.dart` with the six real, navigable screens from `mockups.html` (Ledger, Scan, Edit Entry, Manual Entry, Budgets, Lock), built from a shared component library, wired together with basic navigation and sample data.

**Architecture:** A small reusable widget library (`lib/widgets/`) implements every visual pattern already catalogued in `CLAUDE.md`'s component inventory (buttons, chips, cards, field rows, progress ring/bar, transaction tile, bottom nav, icons). Screens (`lib/screens/`) are thin composition layers over that library — no screen hand-rolls a color, font, or shape that a component or `DESIGN.md` token should supply. A `RootShell` owns bottom-nav tab state and pushes the modal screens (scan, edit, manual entry) via `Navigator`. Data is sample/static for this plan — wiring to Supabase and to the real camera/OCR pipeline are explicitly separate follow-up work, not part of this plan.

**Tech Stack:** Flutter (existing project at `app/`), `flutter_svg` (already added) for icon rendering, existing `StubColors`/`StubText`/`StubButton`/`StubLogo` from prior work.

**Spec:** `DESIGN.md` and `CLAUDE.md` (repo root) — every color, font, and component rule below is copied from there, not invented. `mockups.html` is the pixel-reference for exact structure/copy; a `docs/superpowers/plans/`-adjacent path won't have it open, so the exact markup for each screen is inlined into its task below rather than referenced by line number.

## Global Constraints

- **Colors**: only `StubColors` fields (`app/lib/theme/colors.dart`) or `StubColors.gradPop(brightness)` — never a raw hex in a screen/widget file.
- **Fonts**: only `StubText.archivo()` (UI/labels/body), `StubText.domine()` (brand wordmark only), `StubText.unbounded()` (currency numbers only) — see `DESIGN.md` §1.
- **Blue is always the gradient** (`StubColors.gradPop`), never a flat `StubColors.accentLight`/`accentDark` fill — see `DESIGN.md` §4/§5. The two exceptions: `.tab.active`'s icon (solid `accentStrong`, since SVG `currentColor` can't use the gradient-text trick), and nothing else in the ported screens.
- **Icons**: Tabler icon paths only (`DESIGN.md` §8) — every icon used below is copied verbatim from the existing mockup's inline SVGs, not reinvented.
- **Reuse first**: before writing a new widget, each task's "Consumes" line says what to reuse. Do not duplicate a pattern that already has a component.
- **Verify after every task**: `flutter analyze` must be clean and `flutter test` must pass before moving to the next task. Run from `app/`.

---

## File Structure

```
app/lib/
  models/
    transaction.dart        # Transaction, TransactionSource
    category_spend.dart     # CategorySpend
    budget_limit.dart       # BudgetLimit
  widgets/
    stub_icon.dart           # StubIcon + StubIcons (icon path constants)
    stub_card.dart            # StubCard (generic card surface)
    stub_chip.dart             # StubChip (category filter chip)
    stub_field_row.dart        # StubFieldRow (label+value, edit/manual entry)
    stub_progress_ring.dart    # StubProgressRing (circular gradient ring)
    stub_progress_bar.dart     # StubProgressBar (linear gradient/warn bar)
    stub_transaction_tile.dart # StubTransactionTile (ledger list row)
    stub_bottom_nav.dart       # StubBottomNav, StubNavItem
    stub_button.dart           # (existing)
    stub_logo.dart             # (existing)
  screens/
    ledger_screen.dart
    scan_screen.dart
    edit_entry_screen.dart
    manual_entry_screen.dart
    budgets_screen.dart
    lock_screen.dart
    root_shell.dart           # bottom-nav tab state + modal navigation
  theme/                      # (existing: colors.dart, text.dart, app_theme.dart)
  config/                     # (existing: supabase_config.dart)
  main.dart                   # modified: Lock → RootShell instead of _ThemeCheckScreen
```

---

### Task 1: Data models + fix a stale doc comment

**Files:**
- Create: `app/lib/models/transaction.dart`
- Create: `app/lib/models/category_spend.dart`
- Create: `app/lib/models/budget_limit.dart`
- Modify: `app/lib/theme/colors.dart:41-42`
- Test: `app/test/models_test.dart`

**Interfaces:**
- Produces: `Transaction(merchant, amount, category, source, dateLabel)`, `TransactionSource` enum (`receipt`, `paymentApp`, `bankScreenshot`, `manual`), `CategorySpend(name, amount, color)`, `BudgetLimit(name, spent, limit)` with `.fraction` (double, 0..1.2 clamped) and `.isWarning` (bool, true at ≥90% of limit).

- [ ] **Step 1: Write the failing test**

```dart
// app/test/models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/budget_limit.dart';

void main() {
  test('BudgetLimit computes fraction and warning state', () {
    const onTrack = BudgetLimit(name: 'Groceries', spent: 212, limit: 300);
    expect(onTrack.fraction, closeTo(0.7067, 0.001));
    expect(onTrack.isWarning, isFalse);

    const overBudget = BudgetLimit(name: 'Dining out', spent: 96, limit: 100);
    expect(overBudget.isWarning, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/models_test.dart`
Expected: FAIL — `package:stub/models/budget_limit.dart` doesn't exist.

- [ ] **Step 3: Write the models**

```dart
// app/lib/models/transaction.dart
enum TransactionSource { receipt, paymentApp, bankScreenshot, manual }

class Transaction {
  const Transaction({
    required this.merchant,
    required this.amount,
    required this.category,
    required this.source,
    required this.dateLabel,
  });

  final String merchant;
  final double amount;
  final String category;
  final TransactionSource source;
  final String dateLabel;
}
```

```dart
// app/lib/models/category_spend.dart
import 'package:flutter/material.dart';

class CategorySpend {
  const CategorySpend({required this.name, required this.amount, required this.color});

  final String name;
  final double amount;
  final Color color;
}
```

```dart
// app/lib/models/budget_limit.dart
class BudgetLimit {
  const BudgetLimit({required this.name, required this.spent, required this.limit});

  final String name;
  final double spent;
  final double limit;

  double get fraction => limit == 0 ? 0 : (spent / limit).clamp(0.0, 1.2);
  bool get isWarning => limit == 0 ? false : (spent / limit) >= 0.9;
}
```

Also fix the now-inaccurate doc comment in `colors.dart` (blue buttons use the gradient as of the "blue is always gradient" decision):

```dart
// app/lib/theme/colors.dart:41-42 — replace:
  /// The one decorative gradient ("the pop") — see DESIGN.md §5 for exactly
  /// which elements this is allowed on. Never use it on a button.
// with:
  /// The one decorative gradient ("the pop") — see DESIGN.md §5 for exactly
  /// which elements this is allowed on. As of DESIGN.md §4/§5, every blue
  /// button uses this too — "never on a button" is no longer the rule.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/models_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/models lib/theme/colors.dart test/models_test.dart
git commit -m "feat: add Transaction/CategorySpend/BudgetLimit models"
```

---

### Task 2: Icon system (`StubIcon`, `StubIcons`)

**Files:**
- Create: `app/lib/widgets/stub_icon.dart`
- Test: `app/test/widgets/stub_icon_test.dart`

**Interfaces:**
- Consumes: `flutter_svg`'s `SvgPicture.string` (already a dependency).
- Produces: `StubIcons.home`, `.camera`, `.chartBar`, `.userCircle`, `.receipt`, `.cashBanknote`, `.buildingBank`, `.lock`, `.pencil`, `.x` (each a `String` of raw SVG markup, viewBox `0 0 24 24`). `StubIcon(String data, {double size = 20, required Color color})` widget.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/widgets/stub_icon_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stub/widgets/stub_icon.dart';

void main() {
  testWidgets('StubIcon renders an SvgPicture at the given size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StubIcon(StubIcons.home, size: 24, color: Colors.black),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/widgets/stub_icon_test.dart`
Expected: FAIL — `package:stub/widgets/stub_icon.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

Icon path data below is copied verbatim (same `d=` attributes) from the Tabler icons already used in `mockups.html`.

```dart
// app/lib/widgets/stub_icon.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Raw Tabler icon markup — see DESIGN.md §8 for the library choice and
/// the icon-to-usage mapping. Stroke color in the raw string is ignored;
/// StubIcon always recolors via ColorFilter, so it doesn't matter here.
class StubIcons {
  StubIcons._();

  static const home =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l-2 0l9 -9l9 9l-2 0"/><path d="M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2 -2v-7"/><path d="M9 21v-6a2 2 0 0 1 2 -2h2a2 2 0 0 1 2 2v6"/></svg>';

  static const camera =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 7h1a2 2 0 0 0 2 -2a1 1 0 0 1 1 -1h6a1 1 0 0 1 1 1a2 2 0 0 0 2 2h1a2 2 0 0 1 2 2v9a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-9a2 2 0 0 1 2 -2"/><path d="M9 13a3 3 0 1 0 6 0a3 3 0 0 0 -6 0"/></svg>';

  static const chartBar =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 13a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v6a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -6"/><path d="M15 9a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -10"/><path d="M9 5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v14a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -14"/><path d="M4 20h14"/></svg>';

  static const userCircle =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0"/><path d="M9 10a3 3 0 1 0 6 0a3 3 0 1 0 -6 0"/><path d="M6.168 18.849a4 4 0 0 1 3.832 -2.849h4a4 4 0 0 1 3.834 2.855"/></svg>';

  static const receipt =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 21v-16a2 2 0 0 1 2 -2h10a2 2 0 0 1 2 2v16l-3 -2l-2 2l-2 -2l-2 2l-2 -2l-3 2"/><path d="M14 8h-2.5a1.5 1.5 0 0 0 0 3h1a1.5 1.5 0 0 1 0 3h-2.5m2 0v1.5m0 -9v1.5"/></svg>';

  static const cashBanknote =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 12a3 3 0 1 0 6 0a3 3 0 0 0 -6 0"/><path d="M3 8a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2v8a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2l0 -8"/><path d="M18 12h.01"/><path d="M6 12h.01"/></svg>';

  static const buildingBank =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21l18 0"/><path d="M3 10l18 0"/><path d="M5 6l7 -3l7 3"/><path d="M4 10l0 11"/><path d="M20 10l0 11"/><path d="M8 14l0 3"/><path d="M12 14l0 3"/><path d="M16 14l0 3"/></svg>';

  static const lock =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 13a2 2 0 0 1 2 -2h10a2 2 0 0 1 2 2v6a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2v-6"/><path d="M11 16a1 1 0 1 0 2 0a1 1 0 0 0 -2 0"/><path d="M8 11v-4a4 4 0 1 1 8 0v4"/></svg>';

  static const pencil =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20h4l10.5 -10.5a2.828 2.828 0 1 0 -4 -4l-10.5 10.5v4"/><path d="M13.5 6.5l4 4"/></svg>';

  static const x =
      '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6l-12 12"/><path d="M6 6l12 12"/></svg>';
}

/// Renders one of [StubIcons]' raw SVG strings, recolored to [color].
/// Always use this instead of a Material [Icon] for anything in the
/// DESIGN.md §8 icon table, so icons stay pixel-consistent with the mockup.
class StubIcon extends StatelessWidget {
  const StubIcon(this.data, {super.key, this.size = 20, required this.color});

  final String data;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      data,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/widgets/stub_icon_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/widgets/stub_icon.dart test/widgets/stub_icon_test.dart
git commit -m "feat: add StubIcon icon rendering system"
```

---

### Task 3: `StubCard`

**Files:**
- Create: `app/lib/widgets/stub_card.dart`
- Test: `app/test/widgets/stub_card_test.dart`

**Interfaces:**
- Consumes: `StubColors.surfaceLight`/`surfaceDark`.
- Produces: `StubCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(20)})`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/widgets/stub_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_card.dart';

void main() {
  testWidgets('StubCard renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: StubCard(child: Text('hello'))),
    );
    expect(find.text('hello'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/widgets/stub_card_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/widgets/stub_card.dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// The one card surface style used everywhere (hero totals, category
/// lists, budget rows) — see DESIGN.md §6. Don't hand-roll a Container
/// with its own BoxDecoration in a screen file; use this.
class StubCard extends StatelessWidget {
  const StubCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? StubColors.surfaceDark : StubColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/widgets/stub_card_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/widgets/stub_card.dart test/widgets/stub_card_test.dart
git commit -m "feat: add StubCard"
```

---

### Task 4: `StubChip`

**Files:**
- Create: `app/lib/widgets/stub_chip.dart`
- Test: `app/test/widgets/stub_chip_test.dart`

**Interfaces:**
- Consumes: `StubColors.gradPop`, `StubColors.lineLight/Dark`, `StubColors.surfaceAltLight/Dark`, `StubText.archivo`.
- Produces: `StubChip({required String label, required bool selected, VoidCallback? onTap})`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/widgets/stub_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_chip.dart';

void main() {
  testWidgets('StubChip shows its label and reports taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StubChip(label: 'Groceries', selected: false, onTap: () => tapped = true),
      ),
    );
    expect(find.text('Groceries'), findsOneWidget);
    await tester.tap(find.byType(StubChip));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/widgets/stub_chip_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/widgets/stub_chip.dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';

/// Category filter chip — selected state uses the gradient fill (DESIGN.md
/// §5: "the active category filter chip" is one of the listed gradient
/// uses), unselected is a plain outlined pill.
class StubChip extends StatelessWidget {
  const StubChip({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;
    final surfaceAlt = isDark ? StubColors.surfaceAltDark : StubColors.surfaceAltLight;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final onAccent = isDark ? StubColors.onAccentDark : StubColors.onAccentLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: selected ? null : Border.all(color: line),
          color: selected ? null : surfaceAlt,
          gradient: selected ? StubColors.gradPop(brightness) : null,
        ),
        child: Text(
          label,
          style: StubText.archivo(
            fontSize: 13,
            color: selected ? onAccent : ink.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/widgets/stub_chip_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/widgets/stub_chip.dart test/widgets/stub_chip_test.dart
git commit -m "feat: add StubChip"
```

---

### Task 5: `StubFieldRow`

**Files:**
- Create: `app/lib/widgets/stub_field_row.dart`
- Test: `app/test/widgets/stub_field_row_test.dart`

**Interfaces:**
- Consumes: `StubIcon`/`StubIcons.pencil` (Task 2), `StubText.archivo`/`.unbounded`.
- Produces: `StubFieldRow({required String label, required String value, Color? valueColor, bool mono = false, bool editable = false, VoidCallback? onTap})`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/widgets/stub_field_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_field_row.dart';

void main() {
  testWidgets('StubFieldRow shows label and value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StubFieldRow(label: 'Merchant', value: 'Corner Market'),
      ),
    );
    expect(find.text('MERCHANT'), findsOneWidget);
    expect(find.text('Corner Market'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/widgets/stub_field_row_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/widgets/stub_field_row.dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'stub_icon.dart';

/// Label-over-value row used on Edit Entry and Manual Entry — see the
/// `.field-row` pattern in DESIGN.md's component inventory (CLAUDE.md).
class StubFieldRow extends StatelessWidget {
  const StubFieldRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
    this.editable = false,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;
  final bool editable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final ink30 = ink.withValues(alpha: 0.3);
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;

    final valueStyle = mono
        ? StubText.unbounded(fontSize: 16, color: valueColor ?? ink)
        : StubText.archivo(fontSize: 16, fontWeight: FontWeight.w600, color: valueColor ?? ink);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                  const SizedBox(height: 6),
                  Text(value, style: valueStyle),
                ],
              ),
            ),
            if (editable) StubIcon(StubIcons.pencil, size: 14, color: ink30),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/widgets/stub_field_row_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/widgets/stub_field_row.dart test/widgets/stub_field_row_test.dart
git commit -m "feat: add StubFieldRow"
```

---

### Task 6: `StubProgressRing`

**Files:**
- Create: `app/lib/widgets/stub_progress_ring.dart`
- Test: `app/test/widgets/stub_progress_ring_test.dart`

**Interfaces:**
- Consumes: `StubColors.gradPop`, `StubColors.lineLight/Dark`.
- Produces: `StubProgressRing({required double progress, double size = 56, double strokeWidth = 6})` — `progress` is 0..1.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/widgets/stub_progress_ring_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_progress_ring.dart';

void main() {
  testWidgets('StubProgressRing renders at the given size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: StubProgressRing(progress: 0.674, size: 56))),
    );
    final size = tester.getSize(find.byType(StubProgressRing));
    expect(size.width, 56);
    expect(size.height, 56);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/widgets/stub_progress_ring_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/widgets/stub_progress_ring.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Circular gradient-stroke progress indicator — the dashboard's "left to
/// spend" ring. See DESIGN.md §5: this is one of the fixed gradient uses.
class StubProgressRing extends StatelessWidget {
  const StubProgressRing({super.key, required this.progress, this.size = 56, this.strokeWidth = 6});

  final double progress;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          strokeWidth: strokeWidth,
          trackColor: isDark ? StubColors.lineDark : StubColors.lineLight,
          gradient: StubColors.gradPop(brightness),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.strokeWidth, required this.trackColor, required this.gradient});

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final LinearGradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final fillPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.gradient != gradient;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/widgets/stub_progress_ring_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/widgets/stub_progress_ring.dart test/widgets/stub_progress_ring_test.dart
git commit -m "feat: add StubProgressRing"
```

---

### Task 7: `StubProgressBar`

**Files:**
- Create: `app/lib/widgets/stub_progress_bar.dart`
- Test: `app/test/widgets/stub_progress_bar_test.dart`

**Interfaces:**
- Consumes: `StubColors.gradPop`, `StubColors.warnLight/Dark`, `StubColors.surfaceAltLight/Dark`.
- Produces: `StubProgressBar({required double progress, bool isWarning = false, double height = 7})`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/widgets/stub_progress_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_progress_bar.dart';

void main() {
  testWidgets('StubProgressBar renders at the given height', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SizedBox(width: 200, child: StubProgressBar(progress: 0.71, height: 7))),
      ),
    );
    final size = tester.getSize(find.byType(StubProgressBar));
    expect(size.height, 7);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/widgets/stub_progress_bar_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/widgets/stub_progress_bar.dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Linear budget progress bar. Gradient fill for the normal state; solid
/// `--warn` amber for the over-budget state — DESIGN.md §5: "a warning
/// shouldn't be dressed up decoratively."
class StubProgressBar extends StatelessWidget {
  const StubProgressBar({super.key, required this.progress, this.isWarning = false, this.height = 7});

  final double progress;
  final bool isWarning;
  final double height;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final track = isDark ? StubColors.surfaceAltDark : StubColors.surfaceAltLight;
    final warnColor = isDark ? StubColors.warnDark : StubColors.warnLight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fillWidth = constraints.maxWidth * progress.clamp(0.0, 1.0);
        return Container(
          height: height,
          decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(100)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: fillWidth,
              height: height,
              decoration: BoxDecoration(
                color: isWarning ? warnColor : null,
                gradient: isWarning ? null : StubColors.gradPop(brightness),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/widgets/stub_progress_bar_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/widgets/stub_progress_bar.dart test/widgets/stub_progress_bar_test.dart
git commit -m "feat: add StubProgressBar"
```

---

### Task 8: `StubTransactionTile`

**Files:**
- Create: `app/lib/widgets/stub_transaction_tile.dart`
- Test: `app/test/widgets/stub_transaction_tile_test.dart`

**Interfaces:**
- Consumes: `Transaction`/`TransactionSource` (Task 1), `StubIcon`/`StubIcons` (Task 2).
- Produces: `StubTransactionTile({required Transaction transaction, VoidCallback? onTap})`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/widgets/stub_transaction_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/widgets/stub_transaction_tile.dart';

void main() {
  testWidgets('StubTransactionTile shows merchant, source, and amount', (tester) async {
    const transaction = Transaction(
      merchant: 'Corner Market',
      amount: 18.42,
      category: 'Groceries',
      source: TransactionSource.receipt,
      dateLabel: 'Today',
    );
    await tester.pumpWidget(
      const MaterialApp(home: StubTransactionTile(transaction: transaction)),
    );
    expect(find.text('Corner Market'), findsOneWidget);
    expect(find.textContaining('RECEIPT'), findsOneWidget);
    expect(find.textContaining('18.42'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/widgets/stub_transaction_tile_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/widgets/stub_transaction_tile.dart
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'stub_icon.dart';

class StubTransactionTile extends StatelessWidget {
  const StubTransactionTile({super.key, required this.transaction, this.onTap});

  final Transaction transaction;
  final VoidCallback? onTap;

  String get _sourceLabel {
    switch (transaction.source) {
      case TransactionSource.receipt:
        return 'RECEIPT';
      case TransactionSource.paymentApp:
        return 'PAYMENT APP';
      case TransactionSource.bankScreenshot:
        return 'BANK SCREEN';
      case TransactionSource.manual:
        return 'MANUAL';
    }
  }

  String get _sourceIconData {
    switch (transaction.source) {
      case TransactionSource.receipt:
        return StubIcons.receipt;
      case TransactionSource.paymentApp:
        return StubIcons.cashBanknote;
      case TransactionSource.bankScreenshot:
        return StubIcons.buildingBank;
      case TransactionSource.manual:
        return StubIcons.pencil;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final surfaceAlt = isDark ? StubColors.surfaceAltDark : StubColors.surfaceAltLight;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: surfaceAlt, borderRadius: BorderRadius.circular(8)),
              child: Center(child: StubIcon(_sourceIconData, size: 17, color: ink.withValues(alpha: 0.7))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.merchant, style: StubText.archivo(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
                  const SizedBox(height: 1),
                  Text('$_sourceLabel · ${transaction.dateLabel}', style: StubText.archivo(fontSize: 11, color: ink.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Text('-\$${transaction.amount.toStringAsFixed(2)}', style: StubText.unbounded(fontSize: 14, color: ink)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/widgets/stub_transaction_tile_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/widgets/stub_transaction_tile.dart test/widgets/stub_transaction_tile_test.dart
git commit -m "feat: add StubTransactionTile"
```

---

### Task 9: `StubBottomNav`

**Files:**
- Create: `app/lib/widgets/stub_bottom_nav.dart`
- Test: `app/test/widgets/stub_bottom_nav_test.dart`

**Interfaces:**
- Consumes: `StubIcon`/`StubIcons` (Task 2), `StubColors.gradPop`/`accentStrongLight/Dark`.
- Produces: `StubNavItem(icon: String, label: String)`, `StubBottomNav({required List<StubNavItem> items, required int activeIndex, required ValueChanged<int> onTap, required VoidCallback onScanTap})`. **`items` must have exactly 3 entries** — the mockup's tabbar is `[Home, scan-button, Insights/Budgets, Profile]`, i.e. 3 real tabs with the round scan button fixed in the middle position, not 4 tabs.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/widgets/stub_bottom_nav_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';

void main() {
  testWidgets('StubBottomNav shows all items and reports taps', (tester) async {
    int? tappedIndex;
    var scanTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StubBottomNav(
          items: const [
            StubNavItem(icon: StubIcons.home, label: 'Home'),
            StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
            StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
          ],
          activeIndex: 0,
          onTap: (i) => tappedIndex = i,
          onScanTap: () => scanTapped = true,
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Budgets'));
    expect(tappedIndex, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/widgets/stub_bottom_nav_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/widgets/stub_bottom_nav.dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'stub_icon.dart';

class StubNavItem {
  const StubNavItem({required this.icon, required this.label});

  final String icon;
  final String label;
}

/// Bottom nav bar. Active tab: icon is solid `accentStrong` (DESIGN.md §4's
/// documented exception — SVG `currentColor` can't use the gradient-text
/// trick), label is true gradient text via ShaderMask.
class StubBottomNav extends StatelessWidget {
  const StubBottomNav({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onTap,
    required this.onScanTap,
  }) : assert(items.length == 3, 'StubBottomNav takes exactly 3 items — the scan button is fixed in the middle, not one of them.');

  final List<StubNavItem> items;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final ink30 = (isDark ? StubColors.inkDark : StubColors.inkLight).withValues(alpha: 0.3);
    final accentStrong = isDark ? StubColors.accentStrongDark : StubColors.accentStrongLight;
    final onAccent = isDark ? StubColors.onAccentDark : StubColors.onAccentLight;
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;
    final bg = isDark ? StubColors.bgDark : StubColors.bgLight;

    Widget buildItem(int index) {
      final item = items[index];
      final active = index == activeIndex;
      return GestureDetector(
        onTap: () => onTap(index),
        child: SizedBox(
          width: 48,
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StubIcon(item.icon, size: 18, color: active ? accentStrong : ink30),
              const SizedBox(height: 4),
              active
                  ? ShaderMask(
                      shaderCallback: (rect) => StubColors.gradPop(brightness).createShader(rect),
                      child: Text(item.label, style: StubText.archivo(fontSize: 11, color: Colors.white)),
                    )
                  : Text(item.label, style: StubText.archivo(fontSize: 11, color: ink30)),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: line)), color: bg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          buildItem(0),
          GestureDetector(
            onTap: onScanTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: StubColors.gradPop(brightness)),
              child: Center(child: StubIcon(StubIcons.camera, size: 20, color: onAccent)),
            ),
          ),
          buildItem(1),
          buildItem(2),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/widgets/stub_bottom_nav_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/widgets/stub_bottom_nav.dart test/widgets/stub_bottom_nav_test.dart
git commit -m "feat: add StubBottomNav"
```

---

### Task 10: `LedgerScreen`

**Files:**
- Create: `app/lib/screens/ledger_screen.dart`
- Test: `app/test/screens/ledger_screen_test.dart`

**Interfaces:**
- Consumes: `CategorySpend`, `Transaction` (Task 1); `StubCard` (Task 3); `StubProgressRing` (Task 6); `StubTransactionTile` (Task 8); `StubBottomNav`/`StubNavItem` (Task 9).
- Produces: `LedgerScreen({required String monthLabel, required double leftToSpend, required double leftToSpendFraction, required List<CategorySpend> categories, required List<Transaction> recent, required int activeNavIndex, required List<StubNavItem> navItems, required ValueChanged<int> onNavTap, required VoidCallback onScanTap, ValueChanged<Transaction>? onTransactionTap})`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/screens/ledger_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/category_spend.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/screens/ledger_screen.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';

void main() {
  testWidgets('LedgerScreen shows hero amount, categories, and recent transactions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerScreen(
          monthLabel: 'August',
          leftToSpend: 1842.30,
          leftToSpendFraction: 0.674,
          categories: const [CategorySpend(name: 'Groceries', amount: 212.40, color: Colors.blue)],
          recent: const [
            Transaction(merchant: 'Corner Market', amount: 18.42, category: 'Groceries', source: TransactionSource.receipt, dateLabel: 'Today'),
          ],
          activeNavIndex: 0,
          navItems: const [
            StubNavItem(icon: StubIcons.home, label: 'Home'),
            StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
            StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
          ],
          onNavTap: (_) {},
          onScanTap: () {},
        ),
      ),
    );
    expect(find.textContaining('1,842.30'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Corner Market'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/screens/ledger_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/screens/ledger_screen.dart
import 'package:flutter/material.dart';
import '../models/category_spend.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_progress_ring.dart';
import '../widgets/stub_transaction_tile.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({
    super.key,
    required this.monthLabel,
    required this.leftToSpend,
    required this.leftToSpendFraction,
    required this.categories,
    required this.recent,
    required this.activeNavIndex,
    required this.navItems,
    required this.onNavTap,
    required this.onScanTap,
    this.onTransactionTap,
  });

  final String monthLabel;
  final double leftToSpend;
  final double leftToSpendFraction;
  final List<CategorySpend> categories;
  final List<Transaction> recent;
  final int activeNavIndex;
  final List<StubNavItem> navItems;
  final ValueChanged<int> onNavTap;
  final VoidCallback onScanTap;
  final ValueChanged<Transaction>? onTransactionTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final bg = isDark ? StubColors.bgDark : StubColors.bgLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Stub', style: StubText.domine(fontSize: 18, color: ink)),
                        Text(monthLabel.toUpperCase(), style: StubText.archivo(fontSize: 12, color: ink50, letterSpacing: 0.6)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    StubCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('LEFT TO SPEND', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                                const SizedBox(height: 6),
                                Text('\$${leftToSpend.toStringAsFixed(2)}', style: StubText.unbounded(fontSize: 26, color: ink)),
                              ],
                            ),
                          ),
                          StubProgressRing(progress: leftToSpendFraction),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StubCard(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      child: Column(children: [for (final c in categories) _CategoryRow(category: c)]),
                    ),
                    const SizedBox(height: 22),
                    Text('RECENT', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                    const SizedBox(height: 8),
                    for (final t in recent)
                      StubTransactionTile(transaction: t, onTap: onTransactionTap == null ? null : () => onTransactionTap!(t)),
                  ],
                ),
              ),
            ),
            StubBottomNav(items: navItems, activeIndex: activeNavIndex, onTap: onNavTap, onScanTap: onScanTap),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});
  final CategorySpend category;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: category.color)),
          const SizedBox(width: 10),
          Expanded(child: Text(category.name, style: StubText.archivo(fontSize: 14, color: ink))),
          Text('\$${category.amount.toStringAsFixed(2)}', style: StubText.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/screens/ledger_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/screens/ledger_screen.dart test/screens/ledger_screen_test.dart
git commit -m "feat: add LedgerScreen"
```

---

### Task 11: `ScanScreen`

**Files:**
- Create: `app/lib/screens/scan_screen.dart`
- Test: `app/test/screens/scan_screen_test.dart`

**Scope note:** this is the presentational scan-confirmation screen (parsed result + "Add to ledger"). Wiring it to the real camera and the on-device OCR pipeline (`CLAUDE.md`'s OCR spike decision) is separate follow-up work, not part of this plan — the screen takes already-parsed values as parameters.

**Interfaces:**
- Consumes: `StubButton`/`StubButtonVariant` (existing), `StubCard` (Task 3).
- Produces: `ScanScreen({required String merchant, required double amount, required String category, required VoidCallback onClose, required VoidCallback onAddToLedger})`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/screens/scan_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/scan_screen.dart';

void main() {
  testWidgets('ScanScreen shows parsed fields and confirms on tap', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          merchant: 'Corner Market',
          amount: 18.42,
          category: 'Groceries',
          onClose: () {},
          onAddToLedger: () => confirmed = true,
        ),
      ),
    );
    expect(find.text('Corner Market'), findsOneWidget);
    expect(find.textContaining('18.42'), findsOneWidget);
    await tester.tap(find.text('Add to ledger'));
    expect(confirmed, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/screens/scan_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/screens/scan_screen.dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_icon.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({
    super.key,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.onClose,
    required this.onAddToLedger,
  });

  final String merchant;
  final double amount;
  final String category;
  final VoidCallback onClose;
  final VoidCallback onAddToLedger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final good = isDark ? StubColors.goodDark : StubColors.goodLight;
    final goodBg = good.withValues(alpha: 0.14);

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: onClose),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              StubCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: good, size: 28),
                    const SizedBox(height: 12),
                    _row('MERCHANT', merchant, ink, ink50),
                    _row('AMOUNT', '\$${amount.toStringAsFixed(2)}', ink, ink50, mono: true),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: goodBg, borderRadius: BorderRadius.circular(100)),
                      child: Text(category, style: StubText.archivo(fontSize: 12, fontWeight: FontWeight.w600, color: good)),
                    ),
                    const SizedBox(height: 16),
                    StubButton(label: 'Add to ledger', onPressed: onAddToLedger),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color ink, Color ink50, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: StubText.archivo(fontSize: 11, color: ink50)),
          Text(
            value,
            style: mono
                ? StubText.unbounded(fontSize: 14, color: ink)
                : StubText.archivo(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/screens/scan_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/screens/scan_screen.dart test/screens/scan_screen_test.dart
git commit -m "feat: add ScanScreen"
```

---

### Task 12: `EditEntryScreen`

**Files:**
- Create: `app/lib/screens/edit_entry_screen.dart`
- Test: `app/test/screens/edit_entry_screen_test.dart`

**Interfaces:**
- Consumes: `StubButton`/`StubButtonVariant.save` (existing), `StubChip` (Task 4), `StubFieldRow` (Task 5).
- Produces: `EditEntryScreen({required String merchant, required double amount, required List<String> categories, required String selectedCategory, required String sourceLabel, required VoidCallback onClose, required ValueChanged<String> onSave, required VoidCallback onDelete})`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/screens/edit_entry_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/edit_entry_screen.dart';

void main() {
  testWidgets('EditEntryScreen lets you switch category and save', (tester) async {
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          merchant: 'Corner Market',
          amount: 18.42,
          categories: const ['Groceries', 'Dining', 'Household'],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan · Today',
          onClose: () {},
          onSave: (category) => saved = category,
          onDelete: () {},
        ),
      ),
    );
    expect(find.text('Corner Market'), findsOneWidget);

    await tester.tap(find.text('Dining'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    expect(saved, 'Dining');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/screens/edit_entry_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/screens/edit_entry_screen.dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_chip.dart';
import '../widgets/stub_field_row.dart';
import '../widgets/stub_icon.dart';

class EditEntryScreen extends StatefulWidget {
  const EditEntryScreen({
    super.key,
    required this.merchant,
    required this.amount,
    required this.categories,
    required this.selectedCategory,
    required this.sourceLabel,
    required this.onClose,
    required this.onSave,
    required this.onDelete,
  });

  final String merchant;
  final double amount;
  final List<String> categories;
  final String selectedCategory;
  final String sourceLabel;
  final VoidCallback onClose;
  final ValueChanged<String> onSave;
  final VoidCallback onDelete;

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  late String _selected = widget.selectedCategory;

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StubFieldRow(label: 'Merchant', value: widget.merchant, editable: true),
              StubFieldRow(label: 'Amount', value: '\$${widget.amount.toStringAsFixed(2)}', mono: true, editable: true),
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
              StubButton(label: 'Save changes', variant: StubButtonVariant.save, onPressed: () => widget.onSave(_selected)),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Text('Delete entry', style: StubText.archivo(fontSize: 13, fontWeight: FontWeight.w600, color: danger)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/screens/edit_entry_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/screens/edit_entry_screen.dart test/screens/edit_entry_screen_test.dart
git commit -m "feat: add EditEntryScreen"
```

---

### Task 13: `ManualEntryScreen`

**Files:**
- Create: `app/lib/screens/manual_entry_screen.dart`
- Test: `app/test/screens/manual_entry_screen_test.dart`

**Interfaces:**
- Consumes: `StubButton`/`StubButtonVariant.save` (existing), `StubChip` (Task 4), `StubFieldRow` (Task 5).
- Produces: `ManualEntryScreen({required List<String> categories, required VoidCallback onClose, required void Function(double amount, String merchant, String category) onSave})`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/screens/manual_entry_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/manual_entry_screen.dart';

void main() {
  testWidgets('ManualEntryScreen saves the entered amount and category', (tester) async {
    double? savedAmount;
    String? savedCategory;
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const ['Groceries', 'Dining', 'Transport'],
          onClose: () {},
          onSave: (amount, merchant, category) {
            savedAmount = amount;
            savedCategory = category;
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '12.50');
    await tester.tap(find.text('Dining'));
    await tester.pump();
    await tester.tap(find.text('Save entry'));

    expect(savedAmount, 12.50);
    expect(savedCategory, 'Dining');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/screens/manual_entry_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/screens/manual_entry_screen.dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_chip.dart';
import '../widgets/stub_field_row.dart';
import '../widgets/stub_icon.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({
    super.key,
    required this.categories,
    required this.onClose,
    required this.onSave,
  });

  final List<String> categories;
  final VoidCallback onClose;
  final void Function(double amount, String merchant, String category) onSave;

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _amountController = TextEditingController(text: '0.00');
  final _merchantController = TextEditingController();
  late String _selected = widget.categories.first;

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink30 = ink.withValues(alpha: 0.3);

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: widget.onClose),
        title: Text('New entry', style: StubText.archivo(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    IntrinsicWidth(
                      child: TextField(
                        controller: _amountController,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: StubText.unbounded(fontSize: 32, color: ink),
                        decoration: const InputDecoration(border: InputBorder.none, prefixText: '\$'),
                      ),
                    ),
                    Text('tap to type an amount', style: StubText.archivo(fontSize: 11, letterSpacing: 0.5, color: ink30)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StubFieldRow(
                label: 'Merchant',
                value: _merchantController.text.isEmpty ? 'Add a name' : _merchantController.text,
                valueColor: _merchantController.text.isEmpty ? ink30 : null,
                onTap: () async {
                  final name = await showDialog<String>(
                    context: context,
                    builder: (context) => _MerchantDialog(initial: _merchantController.text),
                  );
                  if (name != null) setState(() => _merchantController.text = name);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CATEGORY', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink30)),
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
              StubFieldRow(label: 'Source', value: 'Manual · cash', valueColor: ink.withValues(alpha: 0.6)),
              const SizedBox(height: 20),
              StubButton(
                label: 'Save entry',
                variant: StubButtonVariant.save,
                onPressed: () {
                  final amount = double.tryParse(_amountController.text) ?? 0;
                  widget.onSave(amount, _merchantController.text, _selected);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MerchantDialog extends StatefulWidget {
  const _MerchantDialog({required this.initial});
  final String initial;

  @override
  State<_MerchantDialog> createState() => _MerchantDialogState();
}

class _MerchantDialogState extends State<_MerchantDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Merchant name'),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Save')),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/screens/manual_entry_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/screens/manual_entry_screen.dart test/screens/manual_entry_screen_test.dart
git commit -m "feat: add ManualEntryScreen"
```

---

### Task 14: `BudgetsScreen`

**Files:**
- Create: `app/lib/screens/budgets_screen.dart`
- Test: `app/test/screens/budgets_screen_test.dart`

**Interfaces:**
- Consumes: `BudgetLimit` (Task 1), `StubCard` (Task 3), `StubProgressBar` (Task 7), `StubBottomNav`/`StubNavItem` (Task 9).
- Produces: `BudgetsScreen({required String monthLabel, required double totalBudgeted, required double totalSpent, required List<BudgetLimit> budgets, required int activeNavIndex, required List<StubNavItem> navItems, required ValueChanged<int> onNavTap, required VoidCallback onScanTap, required VoidCallback onAddCategory})`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/screens/budgets_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/budget_limit.dart';
import 'package:stub/screens/budgets_screen.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';

void main() {
  testWidgets('BudgetsScreen shows total and per-category rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BudgetsScreen(
          monthLabel: 'August',
          totalBudgeted: 2400,
          totalSpent: 1488,
          budgets: const [BudgetLimit(name: 'Groceries', spent: 212, limit: 300)],
          activeNavIndex: 1,
          navItems: const [
            StubNavItem(icon: StubIcons.home, label: 'Home'),
            StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
            StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
          ],
          onNavTap: (_) {},
          onScanTap: () {},
          onAddCategory: () {},
        ),
      ),
    );
    expect(find.textContaining('2400'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('+ Add a category'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/screens/budgets_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/screens/budgets_screen.dart
import 'package:flutter/material.dart';
import '../models/budget_limit.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_progress_bar.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({
    super.key,
    required this.monthLabel,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.budgets,
    required this.activeNavIndex,
    required this.navItems,
    required this.onNavTap,
    required this.onScanTap,
    required this.onAddCategory,
  });

  final String monthLabel;
  final double totalBudgeted;
  final double totalSpent;
  final List<BudgetLimit> budgets;
  final int activeNavIndex;
  final List<StubNavItem> navItems;
  final ValueChanged<int> onNavTap;
  final VoidCallback onScanTap;
  final VoidCallback onAddCategory;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final overallFraction = totalBudgeted == 0 ? 0.0 : (totalSpent / totalBudgeted).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Stub', style: StubText.domine(fontSize: 18, color: ink)),
                        Text(monthLabel.toUpperCase(), style: StubText.archivo(fontSize: 12, color: ink50, letterSpacing: 0.6)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    StubCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BUDGETED THIS MONTH', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                          const SizedBox(height: 6),
                          Text('\$${totalBudgeted.toStringAsFixed(2)}', style: StubText.unbounded(fontSize: 24, color: ink)),
                          const SizedBox(height: 12),
                          StubProgressBar(progress: overallFraction),
                          const SizedBox(height: 8),
                          Text(
                            '\$${totalSpent.toStringAsFixed(0)} spent so far · ${(overallFraction * 100).round()}%',
                            style: StubText.archivo(fontSize: 12, color: ink50),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('CATEGORY LIMITS', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                    const SizedBox(height: 10),
                    StubCard(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      child: Column(children: [for (final b in budgets) _BudgetRow(budget: b)]),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: onAddCategory,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: ink.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('+ Add a category', style: StubText.archivo(fontSize: 13, fontWeight: FontWeight.w600, color: ink50)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            StubBottomNav(items: navItems, activeIndex: activeNavIndex, onTap: onNavTap, onScanTap: onScanTap),
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.budget});
  final BudgetLimit budget;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(budget.name, style: StubText.archivo(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
              Text('\$${budget.spent.toStringAsFixed(0)} / \$${budget.limit.toStringAsFixed(0)}', style: StubText.unbounded(fontSize: 13, color: ink)),
            ],
          ),
          const SizedBox(height: 8),
          StubProgressBar(progress: budget.fraction, isWarning: budget.isWarning),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/screens/budgets_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/screens/budgets_screen.dart test/screens/budgets_screen_test.dart
git commit -m "feat: add BudgetsScreen"
```

---

### Task 15: `LockScreen`

**Files:**
- Create: `app/lib/screens/lock_screen.dart`
- Test: `app/test/screens/lock_screen_test.dart`

**Interfaces:**
- Consumes: `StubIcon`/`StubIcons.lock` (Task 2), `StubColors.gradPop`.
- Produces: `LockScreen({required VoidCallback onUnlock, required VoidCallback onUsePasscode})`.

**Note:** per `DESIGN.md` §4, the lock screen's background is the fixed `--phone-body` color (`0xFF1B1712`), not theme-reactive — this is intentional (the screen always looks like a dark bezel regardless of light/dark app theme), not a bug to "fix" toward `StubColors.bgLight/Dark`.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/screens/lock_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/lock_screen.dart';

void main() {
  testWidgets('LockScreen shows the lock copy and unlocks on tap', (tester) async {
    var unlocked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(onUnlock: () => unlocked = true, onUsePasscode: () {}),
      ),
    );
    expect(find.text('Stub is locked'), findsOneWidget);
    await tester.tap(find.text('Unlock with Face ID'));
    expect(unlocked, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/screens/lock_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/screens/lock_screen.dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_icon.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key, required this.onUnlock, required this.onUsePasscode});

  final VoidCallback onUnlock;
  final VoidCallback onUsePasscode;

  @override
  Widget build(BuildContext context) {
    // Fixed dark bezel — not theme-reactive, see DESIGN.md §4/§2.
    const bezel = Color(0xFF1B1712);
    const paperText = Color(0xFFF3ECDD);

    return Scaffold(
      backgroundColor: bezel,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: paperText.withValues(alpha: 0.3), width: 2),
                ),
                child: Center(child: StubIcon(StubIcons.lock, size: 30, color: paperText.withValues(alpha: 0.85))),
              ),
              const SizedBox(height: 22),
              Text('Stub is locked', style: StubText.domine(fontSize: 20, color: paperText)),
              const SizedBox(height: 6),
              Text('Your ledger, kept private', style: StubText.archivo(fontSize: 13, color: paperText.withValues(alpha: 0.55))),
              const SizedBox(height: 30),
              GestureDetector(
                onTap: onUnlock,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  decoration: BoxDecoration(gradient: StubColors.gradPop(Brightness.dark), borderRadius: BorderRadius.circular(10)),
                  child: Text('Unlock with Face ID', style: StubText.archivo(fontSize: 14, fontWeight: FontWeight.w600, color: StubColors.onAccentDark)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: onUsePasscode,
                child: Text('Use passcode', style: StubText.archivo(fontSize: 12, color: paperText.withValues(alpha: 0.45))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/screens/lock_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/screens/lock_screen.dart test/screens/lock_screen_test.dart
git commit -m "feat: add LockScreen"
```

---

### Task 16: `RootShell` — wire tabs and modal navigation

**Files:**
- Create: `app/lib/screens/root_shell.dart`
- Test: `app/test/screens/root_shell_test.dart`

**Scope note:** sample data matching `mockups.html` exactly — replacing it with real Supabase-backed data is separate follow-up work (see `CLAUDE.md`'s Supabase section: schema isn't designed yet). The "Profile" tab has no screen in the original mockup set either; tapping it falls back to Ledger for now, documented inline, not silently broken.

**Interfaces:**
- Consumes: everything from Tasks 1–15.
- Produces: `RootShell` (a `StatefulWidget`, no constructor params — owns its own sample data and tab state).

- [ ] **Step 1: Write the failing test**

```dart
// app/test/screens/root_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/root_shell.dart';

void main() {
  testWidgets('RootShell starts on the ledger and switches to budgets on tab tap', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RootShell()));
    expect(find.text('LEFT TO SPEND'), findsOneWidget);

    await tester.tap(find.text('Budgets'));
    await tester.pump();
    expect(find.text('BUDGETED THIS MONTH'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/screens/root_shell_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/screens/root_shell.dart
import 'package:flutter/material.dart';
import '../models/budget_limit.dart';
import '../models/category_spend.dart';
import '../models/transaction.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_icon.dart';
import 'budgets_screen.dart';
import 'edit_entry_screen.dart';
import 'ledger_screen.dart';
import 'manual_entry_screen.dart';
import 'scan_screen.dart';

const _navItems = [
  StubNavItem(icon: StubIcons.home, label: 'Home'),
  StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
  StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
];

// Sample data matching mockups.html exactly — replace with real
// Supabase-backed queries once the schema exists (CLAUDE.md's Supabase
// section: not designed yet).
const _sampleCategories = [
  CategorySpend(name: 'Groceries', amount: 212.40, color: Color(0xFF0080FF)),
  CategorySpend(name: 'Dining out', amount: 96.10, color: Color(0xFF4B7A5B)),
  CategorySpend(name: 'Subscriptions', amount: 41.97, color: Color(0xFF8C6A2F)),
  CategorySpend(name: 'Transport', amount: 63.25, color: Color(0xFF5B6B8C)),
];

const _sampleRecent = [
  Transaction(merchant: 'Corner Market', amount: 18.42, category: 'Groceries', source: TransactionSource.receipt, dateLabel: 'Today'),
  Transaction(merchant: 'Sarah K.', amount: 32.00, category: 'Dining out', source: TransactionSource.paymentApp, dateLabel: 'Yesterday'),
  Transaction(merchant: 'Chase Checking', amount: 14.99, category: 'Subscriptions', source: TransactionSource.bankScreenshot, dateLabel: 'Mon'),
];

const _sampleBudgets = [
  BudgetLimit(name: 'Groceries', spent: 212, limit: 300),
  BudgetLimit(name: 'Dining out', spent: 96, limit: 100),
  BudgetLimit(name: 'Subscriptions', spent: 42, limit: 60),
];

/// Owns bottom-nav tab state and pushes the modal screens (scan, edit
/// entry, manual entry). See the scope note in this task for what's
/// intentionally sample data / unimplemented here.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tabIndex = 0;

  void _openScan() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScanScreen(
        merchant: 'Corner Market',
        amount: 18.42,
        category: 'Groceries',
        onClose: () => Navigator.of(context).pop(),
        onAddToLedger: () => Navigator.of(context).pop(),
      ),
    ));
  }

  void _openEditEntry(Transaction transaction) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditEntryScreen(
        merchant: transaction.merchant,
        amount: transaction.amount,
        categories: const ['Groceries', 'Dining', 'Household'],
        selectedCategory: transaction.category,
        sourceLabel: '${transaction.dateLabel}',
        onClose: () => Navigator.of(context).pop(),
        onSave: (_) => Navigator.of(context).pop(),
        onDelete: () => Navigator.of(context).pop(),
      ),
    ));
  }

  void _openManualEntry() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ManualEntryScreen(
        categories: const ['Groceries', 'Dining', 'Transport'],
        onClose: () => Navigator.of(context).pop(),
        onSave: (amount, merchant, category) => Navigator.of(context).pop(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Tab 2 (Profile) has no screen in the original mockup set — falls
    // back to Ledger until a Profile screen is designed.
    if (_tabIndex == 1) {
      return BudgetsScreen(
        monthLabel: 'August',
        totalBudgeted: 2400,
        totalSpent: 1488,
        budgets: _sampleBudgets,
        activeNavIndex: _tabIndex,
        navItems: _navItems,
        onNavTap: (i) => setState(() => _tabIndex = i),
        onScanTap: _openScan,
        onAddCategory: () {},
      );
    }
    return LedgerScreen(
      monthLabel: 'August',
      leftToSpend: 1842.30,
      leftToSpendFraction: 0.674,
      categories: _sampleCategories,
      recent: _sampleRecent,
      activeNavIndex: _tabIndex,
      navItems: _navItems,
      onNavTap: (i) => setState(() => _tabIndex = i),
      onScanTap: _openScan,
      onTransactionTap: _openEditEntry,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/screens/root_shell_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd app && git add lib/screens/root_shell.dart test/screens/root_shell_test.dart
git commit -m "feat: add RootShell tab navigation"
```

---

### Task 17: Wire `main.dart` — Lock → RootShell, replacing the temporary check screen

**Files:**
- Modify: `app/lib/main.dart`
- Test: `app/test/widget_test.dart` (existing — update, since `_ThemeCheckScreen` is being removed)

**Interfaces:**
- Consumes: `LockScreen` (Task 15), `RootShell` (Task 16).

- [ ] **Step 1: Update the existing smoke test to match the new entry flow**

```dart
// app/test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:stub/main.dart';

void main() {
  testWidgets('App boots locked and unlocks into the ledger', (tester) async {
    await tester.pumpWidget(const StubApp());

    expect(find.text('Stub is locked'), findsOneWidget);

    await tester.tap(find.text('Unlock with Face ID'));
    await tester.pump();

    expect(find.text('LEFT TO SPEND'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/widget_test.dart`
Expected: FAIL — `main.dart` still shows `_ThemeCheckScreen`, not the lock screen.

- [ ] **Step 3: Update `main.dart`**

```dart
// app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/lock_screen.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const StubApp());
}

class StubApp extends StatelessWidget {
  const StubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stub',
      debugShowCheckedModeBanner: false,
      theme: StubTheme.light(),
      darkTheme: StubTheme.dark(),
      themeMode: ThemeMode.system,
      home: const _LockGate(),
    );
  }
}

/// Shows the lock screen until unlocked, then the real app. Real Face
/// ID/biometric wiring (the `local_auth` package is already a dependency)
/// is separate follow-up work — this just gates on a boolean for now, so
/// the screen and the navigation shell are both real and testable before
/// that wiring exists.
class _LockGate extends StatefulWidget {
  const _LockGate();

  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return const RootShell();
    return LockScreen(
      onUnlock: () => setState(() => _unlocked = true),
      onUsePasscode: () => setState(() => _unlocked = true),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd app && flutter test test/widget_test.dart`
Expected: PASS

- [ ] **Step 5: Full-suite check and commit**

Run: `cd app && flutter analyze && flutter test`
Expected: `flutter analyze` → "No issues found!"; `flutter test` → all tests (every task's test plus this one) pass.

```bash
cd app && git add lib/main.dart test/widget_test.dart
git commit -m "feat: wire LockScreen -> RootShell as the real app entry flow"
```

---

### Task 18: Update `CLAUDE.md`'s component inventory and status

**Files:**
- Modify: `CLAUDE.md` (repo root) — Component inventory table, and the Flutter project "Status" line.

- [ ] **Step 1: Add every new component to the Component inventory table**

Add rows for: `StubIcon`/`StubIcons` (`lib/widgets/stub_icon.dart`), `StubCard` (`lib/widgets/stub_card.dart`), `StubChip` (`lib/widgets/stub_chip.dart`), `StubFieldRow` (`lib/widgets/stub_field_row.dart`), `StubProgressRing` (`lib/widgets/stub_progress_ring.dart`), `StubProgressBar` (`lib/widgets/stub_progress_bar.dart`), `StubTransactionTile` (`lib/widgets/stub_transaction_tile.dart`), `StubBottomNav`/`StubNavItem` (`lib/widgets/stub_bottom_nav.dart`) — one row each, matching the existing table's format (Component | Where it's defined | Variants).

- [ ] **Step 2: Update the Flutter project "Status" paragraph**

Replace the "No real screens ported yet" sentence with: all six screens (Ledger, Scan, Edit Entry, Manual Entry, Budgets, Lock) ported and wired via `RootShell`; `main.dart` now gates on `LockScreen` before showing the real app; data is sample/static pending the Supabase schema (still not designed — see the Supabase section) and the real camera/OCR pipeline (see the OCR spike section) wiring.

- [ ] **Step 3: Update the File map table**

Add rows for every new file under `app/lib/widgets/` and `app/lib/screens/`, and change the `app/lib/screens/` row (currently "Empty so far") to point at `root_shell.dart` as the entry point.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md component inventory and status after screen port"
```

---

## Self-Review

**Spec coverage**: All 6 navigable mockup screens (Ledger, Scan, Edit Entry, Manual Entry, Budgets, Lock) have a task. The 7th mockup ("widget") is explicitly out of scope (it's an OS home-screen widget, a different implementation surface — WidgetKit/Glance, not a Flutter screen), noted in this plan's architecture line and in Task 16's scope note, not silently dropped. Every color/font/gradient rule from `DESIGN.md` §1–§5 has a corresponding "Consumes"/inline comment tying the code back to the rule (StubText 3-font system, gradient-only-on-blue, the two documented exceptions in `StubBottomNav`). `CLAUDE.md`'s reuse-first rule is enforced structurally — every screen task's "Consumes" line points at an earlier task's component, no screen defines its own button/chip/card style.

**Placeholder scan**: no TBD/TODO markers; every code block is complete, runnable Dart, not a sketch. The two explicit scope notes (Scan screen's camera/OCR wiring, RootShell's Profile tab and Supabase data) are documented decisions with a stated reason, not vague "handle later" placeholders — both are real, bounded follow-up work named in `CLAUDE.md`'s existing Open Items.

**Type consistency**: `Transaction`/`CategorySpend`/`BudgetLimit` (Task 1) are used with identical field names in every later task that consumes them (checked against Tasks 8, 10, 14, 16). `StubNavItem`/`StubBottomNav`'s 3-item contract (Task 9) matches how `LedgerScreen`, `BudgetsScreen`, and `RootShell` all construct exactly 3-item `navItems` lists. `StubButtonVariant.save` (existing) is referenced identically in Tasks 12 and 13.

---

**Plan complete and saved to `docs/superpowers/plans/2026-08-26-port-mockup-screens.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
