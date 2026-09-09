# Siri Shortcuts Quick-Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user log an expense via an iOS Shortcuts automation, which
deep-links into a pre-filled `ManualEntryScreen` for a one-tap confirm —
not a silent background save.

**Architecture:** A native iOS `AppIntent` opens a
`com.stubapp.stub://log-expense?amount=...&merchant=...` URL. A new
`DeepLinkService` abstraction (real impl via the `app_links` package,
fake for tests — same interface+fake pattern every other service in this
codebase already uses) delivers incoming links to `StubApp`, which holds
the parsed value until `RootShell` is actually built (i.e. post-unlock),
then hands it through once. `RootShell` pushes `ManualEntryScreen`
pre-filled through its existing `_openManualEntry`/save path — nothing
new writes to `TransactionRepository`.

**Tech Stack:** Flutter/Dart, Swift (iOS `AppIntents` framework, iOS 16+),
the `app_links` package.

**Spec:** `docs/superpowers/specs/2026-09-08-siri-shortcuts-quick-log-design.md`

## Global Constraints

- Never a silent background save — every path ends at `ManualEntryScreen`
  for user confirmation, same as OCR scans already require.
- No category parameter on the Shortcuts action itself — category is
  always picked in-app.
- Reuse the existing `com.stubapp.stub://` URL scheme — do not register a
  second one.
- A malformed/missing `amount` in the link must never crash — it just
  means `ManualEntryScreen` opens at its normal `$0.00` default.
- `flutter pub add <package>` for any new dependency — never hand-type a
  version into `pubspec.yaml`.
- Run `flutter analyze` (must be clean) and `flutter test` (must pass)
  from `app/` before considering any task done.

---

### Task 1: Pure deep-link parsing

**Files:**
- Create: `app/lib/util/deep_link.dart`
- Test: `app/test/util/deep_link_test.dart`

**Interfaces:**
- Produces: `class ParsedDeepLink { const ParsedDeepLink({this.amount, this.merchant}); final double? amount; final String? merchant; }`
  and `ParsedDeepLink? parseDeepLink(Uri uri)`. Later tasks call
  `parseDeepLink` and read `.amount`/`.merchant` off the result.

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/util/deep_link_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/util/deep_link.dart';

void main() {
  test('parses amount and merchant from a valid log-expense link', () {
    final result = parseDeepLink(Uri.parse('com.stubapp.stub://log-expense?amount=12.50&merchant=Starbucks'));
    expect(result, isNotNull);
    expect(result!.amount, 12.50);
    expect(result.merchant, 'Starbucks');
  });

  test('merchant is null when omitted', () {
    final result = parseDeepLink(Uri.parse('com.stubapp.stub://log-expense?amount=12.50'));
    expect(result, isNotNull);
    expect(result!.amount, 12.50);
    expect(result.merchant, isNull);
  });

  test('merchant is null when present but empty', () {
    final result = parseDeepLink(Uri.parse('com.stubapp.stub://log-expense?amount=12.50&merchant='));
    expect(result!.merchant, isNull);
  });

  test('amount is null when missing or malformed, not an error', () {
    expect(parseDeepLink(Uri.parse('com.stubapp.stub://log-expense')).let((r) => r!.amount), isNull);
    expect(parseDeepLink(Uri.parse('com.stubapp.stub://log-expense?amount=notanumber')).let((r) => r!.amount), isNull);
  });

  test('returns null for a link with a different host (e.g. the auth callback)', () {
    expect(parseDeepLink(Uri.parse('com.stubapp.stub://login-callback?code=abc')), isNull);
  });

  test('returns null for a completely unrelated URI', () {
    expect(parseDeepLink(Uri.parse('https://example.com')), isNull);
  });
}
```

Note: Dart has no built-in `.let()` extension — replace those two lines
with plain local variables instead:

```dart
  test('amount is null when missing or malformed, not an error', () {
    final missing = parseDeepLink(Uri.parse('com.stubapp.stub://log-expense'));
    expect(missing!.amount, isNull);
    final malformed = parseDeepLink(Uri.parse('com.stubapp.stub://log-expense?amount=notanumber'));
    expect(malformed!.amount, isNull);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `app/`): `flutter test test/util/deep_link_test.dart`
Expected: FAIL — `package:stub/util/deep_link.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// app/lib/util/deep_link.dart

/// A parsed `com.stubapp.stub://log-expense` deep link, handed off by
/// `LogExpenseIntent` (see ios/Runner/LogExpenseIntent.swift) so a
/// Shortcuts automation can pre-fill `ManualEntryScreen` for a one-tap
/// confirm — never a silent save.
class ParsedDeepLink {
  const ParsedDeepLink({this.amount, this.merchant});
  final double? amount;
  final String? merchant;
}

/// Null for anything that isn't a recognized `log-expense` link (e.g. the
/// existing `login-callback` auth link, or an unrelated URI) — callers
/// should just ignore those, not treat them as errors. A malformed or
/// missing `amount` inside a recognized link still returns a
/// [ParsedDeepLink] (with `amount: null`), since the caller falls back to
/// `ManualEntryScreen`'s own default in that case rather than failing.
ParsedDeepLink? parseDeepLink(Uri uri) {
  if (uri.scheme != 'com.stubapp.stub' || uri.host != 'log-expense') return null;
  final amountText = uri.queryParameters['amount'];
  final amount = amountText == null ? null : double.tryParse(amountText);
  final merchant = uri.queryParameters['merchant'];
  return ParsedDeepLink(amount: amount, merchant: (merchant == null || merchant.isEmpty) ? null : merchant);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/util/deep_link_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Run full analyze/test and commit**

Run: `flutter analyze && flutter test`
Expected: both clean.

```bash
git add app/lib/util/deep_link.dart app/test/util/deep_link_test.dart
git commit -m "feat: add pure deep-link parsing for the log-expense URL

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: `DeepLinkService` abstraction + fake

**Files:**
- Create: `app/lib/data/deep_link_service.dart`
- Modify: `app/lib/data/fakes.dart` (add `FakeDeepLinkService` at the end,
  matching the existing pattern for `FakeNotificationService`)

**Interfaces:**
- Consumes: nothing new.
- Produces: `abstract class DeepLinkService { Future<Uri?> getInitialLink(); Stream<Uri> get onLink; }`
  and `class FakeDeepLinkService implements DeepLinkService` with a
  settable `initialLink` and an `emit(Uri uri)` method test code calls to
  simulate an incoming link while the app is running. Task 5 (main.dart)
  and Task 6 (the real impl) both implement/consume this interface.

- [ ] **Step 1: Write the interface**

```dart
// app/lib/data/deep_link_service.dart

/// Delivers incoming `com.stubapp.stub://...` deep links (see
/// `util/deep_link.dart` for what's actually parsed out of them) —
/// currently only the Siri Shortcuts quick-log feature uses this, but the
/// interface is generic over any incoming link, matching
/// `supabase_flutter`'s own separate internal listener for its
/// `login-callback` auth link (both listen independently; each only acts
/// on the path it recognizes).
abstract class DeepLinkService {
  /// The link that cold-launched the app, if any — checked once at
  /// startup. Null if the app wasn't launched via a link.
  Future<Uri?> getInitialLink();

  /// Links received while the app is already running (warm).
  Stream<Uri> get onLink;
}
```

- [ ] **Step 2: Add the fake**

Open `app/lib/data/fakes.dart`. Add this import near the top, alongside
the other `data/` imports:

```dart
import 'deep_link_service.dart';
```

Add this class at the end of the file, after `FakeNotificationService`:

```dart
class FakeDeepLinkService implements DeepLinkService {
  FakeDeepLinkService({this.initialLink});
  Uri? initialLink;
  final _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => initialLink;

  @override
  Stream<Uri> get onLink => _controller.stream;

  /// Test helper — simulates a link arriving while the app is running.
  void emit(Uri uri) => _controller.add(uri);
}
```

`dart:async`'s `StreamController` is already imported in this file (used
by `FakeAccountLinkService`) — no new import needed for that part.

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze`
Expected: clean (no test exercises this yet — it's exercised indirectly
in Tasks 4 and 5).

- [ ] **Step 4: Commit**

```bash
git add app/lib/data/deep_link_service.dart app/lib/data/fakes.dart
git commit -m "feat: add DeepLinkService interface and fake

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: `ManualEntryScreen` pre-fill support

**Files:**
- Modify: `app/lib/screens/manual_entry_screen.dart`
- Test: `app/test/screens/manual_entry_screen_test.dart`

**Interfaces:**
- Consumes: nothing new (plain `double?`/`String?` values).
- Produces: `ManualEntryScreen`'s constructor gains two optional named
  params, `initialAmount` (`double?`) and `initialMerchant` (`String?`).
  Task 4 passes these through from `RootShell`.

The current constructor (for reference — do not repaste this, just add
to it):

```dart
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
```

And its state's field declarations:

```dart
class _ManualEntryScreenState extends State<ManualEntryScreen> {
  static const _maxAmount = 10000000000.0;

  final _amountController = TextEditingController(text: '0.00');
  final _merchantController = TextEditingController();
  late String _selected = widget.categories.first;
```

- [ ] **Step 1: Write the failing test**

Add to the end of `app/test/screens/manual_entry_screen_test.dart`
(inside the existing `void main() { ... }`, as a new `testWidgets`
alongside the others):

```dart
  testWidgets('Pre-fills the amount and merchant when given initial values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const ['Groceries'],
          initialAmount: 12.50,
          initialMerchant: 'Starbucks',
          onClose: () {},
          onSave: (amount, merchant, category) {},
        ),
      ),
    );

    expect(find.text(r'$12.50'), findsOneWidget);
    expect(find.text('Starbucks'), findsOneWidget);
  });

  testWidgets('Still defaults to $0.00 and "Add a name" when no initial values are given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const ['Groceries'],
          onClose: () {},
          onSave: (amount, merchant, category) {},
        ),
      ),
    );

    expect(find.text(r'$0.00'), findsOneWidget);
    expect(find.text('Add a name'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the tests to verify the first one fails**

Run: `flutter test test/screens/manual_entry_screen_test.dart`
Expected: the new "Pre-fills" test FAILs (`initialAmount`/`initialMerchant`
aren't defined params yet); the "Still defaults" test already passes
(current behavior).

- [ ] **Step 3: Add the two params and pre-fill the controllers**

In `app/lib/screens/manual_entry_screen.dart`, change the constructor to:

```dart
class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({
    super.key,
    required this.categories,
    required this.onClose,
    required this.onSave,
    this.initialAmount,
    this.initialMerchant,
  });

  final List<String> categories;
  final VoidCallback onClose;
  final void Function(double amount, String merchant, String category) onSave;
  /// Pre-fills the amount/merchant fields — used when this screen is
  /// opened from a Siri Shortcuts quick-log deep link (see
  /// `RootShell`'s `initialManualEntryAmount`/`initialManualEntryMerchant`).
  /// Both null in every other entry point into this screen.
  final double? initialAmount;
  final String? initialMerchant;
```

Change the state's controller initialization to use them:

```dart
class _ManualEntryScreenState extends State<ManualEntryScreen> {
  static const _maxAmount = 10000000000.0;

  late final _amountController = TextEditingController(
    text: widget.initialAmount == null ? '0.00' : widget.initialAmount!.toStringAsFixed(2),
  );
  late final _merchantController = TextEditingController(text: widget.initialMerchant ?? '');
  late String _selected = widget.categories.first;
```

(`_amountController`/`_merchantController` change from `final` to
`late final` here because their initializer now reads `widget.*`, which
isn't available in a plain `final` field initializer list — this is a
mechanical change, not a behavior change for the no-initial-value case.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/screens/manual_entry_screen_test.dart`
Expected: PASS (all tests in the file, including the two new ones and
the pre-existing three).

- [ ] **Step 5: Run full analyze/test and commit**

Run: `flutter analyze && flutter test`
Expected: both clean.

```bash
git add app/lib/screens/manual_entry_screen.dart app/test/screens/manual_entry_screen_test.dart
git commit -m "feat: let ManualEntryScreen be pre-filled with an initial amount/merchant

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: `RootShell` one-shot pending-link consumption

**Files:**
- Modify: `app/lib/screens/root_shell.dart`
- Test: `app/test/screens/root_shell_test.dart`

**Interfaces:**
- Consumes: `ManualEntryScreen`'s `initialAmount`/`initialMerchant` (Task 3).
- Produces: `RootShell`'s constructor gains two optional named params,
  `initialManualEntryAmount` (`double?`) and `initialManualEntryMerchant`
  (`String?`). Task 5 (`StubApp`) passes these through exactly once per
  non-null value received.

`RootShell`'s current constructor (for reference):

```dart
class RootShell extends StatefulWidget {
  const RootShell({
    super.key,
    required this.categoryRepository,
    required this.transactionRepository,
    required this.budgetRepository,
    required this.accountLinkService,
    required this.themeModeNotifier,
    required this.currencyNotifier,
    required this.lockEnabledNotifier,
    required this.lockSupported,
    required this.localPrefs,
    required this.textRecognitionService,
    required this.notificationService,
  });
```

`_openManualEntry` today (around line 507):

```dart
  void _openManualEntry(List<Category> categories) {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a category first, then log an expense.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ManualEntryScreen(
        categories: [for (final c in categories) c.name],
        onClose: () => Navigator.of(context).pop(),
        onSave: (amount, merchant, categoryName) => _guardedWrite(() async {
          final category = categories.firstWhere((c) => c.name == categoryName);
          await widget.transactionRepository.create(Transaction(
            id: '',
            categoryId: category.id,
            merchant: merchant,
            amount: amount,
            category: categoryName,
            source: TransactionSource.manual,
            occurredAt: DateTime.now(),
          ));
        }, onSuccess: () => Navigator.of(context).pop()),
      ),
    ));
  }
```

And the `build()` method's `FutureBuilder`, right after the `if (data ==
null) { ... }` early-return block (around line 578-584):

```dart
        // A reload that fails while we already have `_lastData` (e.g. a
        // transient network blip on a background refresh) just keeps
        // showing that last-known-good data rather than replacing the
        // whole screen with a hard error — only the true first load (no
        // data at all yet) surfaces the retry screen above.

        final Widget content;

        if (_tabIndex == 1) {
```

- [ ] **Step 1: Write the failing test**

Add to `app/test/screens/root_shell_test.dart`, near the other
`_openManualEntry`-related tests (e.g. right after "Tapping Manual Entry
FAB with zero categories shows a snackbar and does not push
ManualEntryScreen"):

```dart
  testWidgets('A pending initialManualEntryAmount/Merchant opens ManualEntryScreen pre-filled, exactly once', (tester) async {
    final categories = FakeCategoryRepository();
    await categories.create('Groceries');

    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: categories,
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      currencyNotifier: ValueNotifier<String>("USD"),
      localPrefs: LocalPrefs(),
      textRecognitionService: FakeTextRecognitionService(),
      notificationService: FakeNotificationService(),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      lockSupported: true,
      initialManualEntryAmount: 12.50,
      initialManualEntryMerchant: 'Starbucks',
    )));
    await tester.pumpAndSettle();

    expect(find.byType(ManualEntryScreen), findsOneWidget);
    expect(find.text(r'$12.50'), findsOneWidget);
    expect(find.text('Starbucks'), findsOneWidget);

    // Closing and pulling to refresh must not re-open it a second time —
    // the pending value is consumed exactly once.
    await tester.tap(find.byIcon(Icons.close).evaluate().isNotEmpty
        ? find.byIcon(Icons.close)
        : find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(find.byType(ManualEntryScreen), findsNothing);
  });
```

Note: check which close-icon finder actually matches once you run this —
`ManualEntryScreen`'s close button uses `StubIcon(StubIcons.x, ...)`
inside an `IconButton`, not a Material `Icons.close`, so simplify that
tap to `find.byType(IconButton).first` and drop the `Icons.close`
fallback branch entirely:

```dart
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();
    expect(find.byType(ManualEntryScreen), findsNothing);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/screens/root_shell_test.dart`
Expected: FAIL — `initialManualEntryAmount`/`initialManualEntryMerchant`
aren't defined constructor params yet.

- [ ] **Step 3: Add the params, a one-shot guard field, and the
      auto-open logic**

In `app/lib/screens/root_shell.dart`, add the two new params to
`RootShell`'s constructor:

```dart
class RootShell extends StatefulWidget {
  const RootShell({
    super.key,
    required this.categoryRepository,
    required this.transactionRepository,
    required this.budgetRepository,
    required this.accountLinkService,
    required this.themeModeNotifier,
    required this.currencyNotifier,
    required this.lockEnabledNotifier,
    required this.lockSupported,
    required this.localPrefs,
    required this.textRecognitionService,
    required this.notificationService,
    this.initialManualEntryAmount,
    this.initialManualEntryMerchant,
  });
```

and the two new fields alongside the others:

```dart
  final NotificationService notificationService;
  /// Set once, by `StubApp`, when the app was opened via a
  /// `com.stubapp.stub://log-expense` Siri Shortcuts deep link (see
  /// `util/deep_link.dart`). `StubApp` clears its own pending state
  /// immediately after passing these along, so they're only ever
  /// non-null on the one build where they should actually open
  /// `ManualEntryScreen`.
  final double? initialManualEntryAmount;
  final String? initialManualEntryMerchant;
```

Add a one-shot guard field to `_RootShellState`, alongside `_lastData`:

```dart
  _ShellData? _lastData;
  // Guards against re-opening ManualEntryScreen if this widget rebuilds
  // for an unrelated reason (tab switch, reload) after already consuming
  // widget.initialManualEntryAmount/Merchant once.
  bool _consumedPendingManualEntry = false;
```

Update `_openManualEntry` to accept the optional pre-fill values and pass
them through:

```dart
  void _openManualEntry(List<Category> categories, {double? initialAmount, String? initialMerchant}) {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a category first, then log an expense.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ManualEntryScreen(
        categories: [for (final c in categories) c.name],
        initialAmount: initialAmount,
        initialMerchant: initialMerchant,
        onClose: () => Navigator.of(context).pop(),
        onSave: (amount, merchant, categoryName) => _guardedWrite(() async {
          final category = categories.firstWhere((c) => c.name == categoryName);
          await widget.transactionRepository.create(Transaction(
            id: '',
            categoryId: category.id,
            merchant: merchant,
            amount: amount,
            category: categoryName,
            source: TransactionSource.manual,
            occurredAt: DateTime.now(),
          ));
        }, onSuccess: () => Navigator.of(context).pop()),
      ),
    ));
  }
```

Finally, in `build()`, right after the `if (data == null) { ... }`
early-return block and its trailing comment (i.e. immediately before
`final Widget content;`), add the auto-open trigger:

```dart
        if (!_consumedPendingManualEntry &&
            (widget.initialManualEntryAmount != null || widget.initialManualEntryMerchant != null)) {
          _consumedPendingManualEntry = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openManualEntry(
                data.categories,
                initialAmount: widget.initialManualEntryAmount,
                initialMerchant: widget.initialManualEntryMerchant,
              );
            }
          });
        }

        final Widget content;
```

(The `addPostFrameCallback` defers the `Navigator.push` until after this
`build()` call finishes — pushing a route from the middle of a `build()`
throws.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/screens/root_shell_test.dart`
Expected: PASS (all tests in the file, including the new one).

- [ ] **Step 5: Run full analyze/test and commit**

Run: `flutter analyze && flutter test`
Expected: both clean.

```bash
git add app/lib/screens/root_shell.dart app/test/screens/root_shell_test.dart
git commit -m "feat: RootShell opens ManualEntryScreen pre-filled from a pending deep link

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: `StubApp`/`main.dart` deep-link wiring

**Files:**
- Modify: `app/lib/main.dart`
- Test: `app/test/widget_test.dart`

**Interfaces:**
- Consumes: `DeepLinkService` (Task 2), `parseDeepLink` (Task 1),
  `RootShell.initialManualEntryAmount`/`initialManualEntryMerchant`
  (Task 4).
- Produces: `StubApp`'s constructor gains a new required
  `deepLinkService: DeepLinkService` param. `_StartupGate` (the only
  current caller of `StubApp` outside tests) is updated to pass a real
  instance — but that real instance (`AppLinksDeepLinkService`) isn't
  built until Task 6, so **this task temporarily wires it to a
  not-yet-existing type**. To keep this task's own tests green without
  needing Task 6 done first, use a small inline placeholder in
  `_StartupGate` for now (removed/replaced in Task 6's Step 1):

```dart
class _PlaceholderDeepLinkService implements DeepLinkService {
  @override
  Future<Uri?> getInitialLink() async => null;
  @override
  Stream<Uri> get onLink => const Stream.empty();
}
```

(This keeps `main.dart` compiling end-to-end after this task, without
pulling in the `app_links` package yet. Task 6 deletes this class and
replaces its one call site.)

- [ ] **Step 1: Write the failing test**

Add to `app/test/widget_test.dart`, near the other `StubApp` tests:

```dart
  testWidgets('A pending deep link opens ManualEntryScreen pre-filled once unlocked', (tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_backup_prompt': true});
    final deepLinks = FakeDeepLinkService(
      initialLink: Uri.parse('com.stubapp.stub://log-expense?amount=12.50&merchant=Starbucks'),
    );
    final categories = FakeCategoryRepository();
    await categories.create('Groceries');

    await tester.pumpWidget(StubApp(
      categoryRepository: categories,
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      localPrefs: LocalPrefs(),
      themeModeNotifier: ValueNotifier<ThemeMode>(ThemeMode.system),
      currencyNotifier: ValueNotifier<String>("USD"),
      textRecognitionService: FakeTextRecognitionService(),
      deviceAuthService: FakeDeviceAuthService(),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      notificationService: FakeNotificationService(),
      deepLinkService: deepLinks,
    ));
    await tester.pump();

    // Still locked — the link must wait, not open ManualEntryScreen
    // behind/through the lock screen.
    expect(find.text('Stub is locked'), findsOneWidget);
    expect(find.byType(ManualEntryScreen), findsNothing);

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.byType(ManualEntryScreen), findsOneWidget);
    expect(find.text(r'$12.50'), findsOneWidget);
    expect(find.text('Starbucks'), findsOneWidget);
  });
```

Add the two new imports this test needs at the top of the file:

```dart
import 'package:stub/screens/manual_entry_screen.dart';
```

(`FakeDeepLinkService` comes from the same `package:stub/data/fakes.dart`
import already in this file.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `deepLinkService` isn't a defined `StubApp` param yet.

- [ ] **Step 3: Wire it up in `main.dart`**

Add the import (alongside the other `data/` imports):

```dart
import 'data/deep_link_service.dart';
```

and (temporarily, per this task's Interfaces note above) define the
placeholder near the top of the file, after the imports:

```dart
/// Temporary — replaced by `AppLinksDeepLinkService` in the next task,
/// once the `app_links` package is added. Keeps this task's own tests
/// green without pulling in a new dependency here.
class _PlaceholderDeepLinkService implements DeepLinkService {
  @override
  Future<Uri?> getInitialLink() async => null;
  @override
  Stream<Uri> get onLink => const Stream.empty();
}
```

Add the param to `StubApp`'s `_StartupGate` call site:

```dart
        return StubApp(
          categoryRepository: SupabaseCategoryRepository(Supabase.instance.client),
          transactionRepository: SupabaseTransactionRepository(Supabase.instance.client),
          budgetRepository: SupabaseBudgetRepository(Supabase.instance.client),
          accountLinkService: SupabaseAccountLinkService(Supabase.instance.client),
          localPrefs: result.localPrefs,
          themeModeNotifier: result.themeModeNotifier,
          currencyNotifier: result.currencyNotifier,
          lockEnabledNotifier: result.lockEnabledNotifier,
          textRecognitionService: MlKitTextRecognitionService(),
          deviceAuthService: LocalAuthDeviceAuthService(),
          notificationService: LocalNotificationsService(),
          deepLinkService: _PlaceholderDeepLinkService(),
        );
```

Add the param + field to the `StubApp` widget class:

```dart
class StubApp extends StatefulWidget {
  const StubApp({
    super.key,
    required this.categoryRepository,
    required this.transactionRepository,
    required this.budgetRepository,
    required this.accountLinkService,
    required this.localPrefs,
    required this.themeModeNotifier,
    required this.currencyNotifier,
    required this.lockEnabledNotifier,
    required this.textRecognitionService,
    required this.deviceAuthService,
    required this.notificationService,
    required this.deepLinkService,
  });

  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;
  final AccountLinkService accountLinkService;
  final LocalPrefs localPrefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<String> currencyNotifier;
  final ValueNotifier<bool> lockEnabledNotifier;
  final TextRecognitionService textRecognitionService;
  final DeviceAuthService deviceAuthService;
  final NotificationService notificationService;
  final DeepLinkService deepLinkService;
```

Add pending-link state, a listener, and the handler to `_StubAppState`:

```dart
class _StubAppState extends State<StubApp> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool? _supported;
  bool? _showBackupPrompt;
  double? _pendingManualEntryAmount;
  String? _pendingManualEntryMerchant;
  StreamSubscription<Uri>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.currencyNotifier.addListener(_syncCurrencyConfig);
    widget.lockEnabledNotifier.addListener(_onLockEnabledChanged);
    _checkSupport();
    _listenForDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.currencyNotifier.removeListener(_syncCurrencyConfig);
    widget.lockEnabledNotifier.removeListener(_onLockEnabledChanged);
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  /// A failure here (permission issue, platform channel error) must
  /// never block startup — this is purely a nice-to-have on top of the
  /// app's normal launch.
  Future<void> _listenForDeepLinks() async {
    try {
      final initial = await widget.deepLinkService.getInitialLink();
      if (initial != null) _handleIncomingLink(initial);
    } catch (_) {}
    _deepLinkSubscription = widget.deepLinkService.onLink.listen(
      _handleIncomingLink,
      onError: (_) {},
    );
  }

  void _handleIncomingLink(Uri uri) {
    final parsed = parseDeepLink(uri);
    if (parsed == null) return;
    if (!mounted) return;
    setState(() {
      _pendingManualEntryAmount = parsed.amount;
      _pendingManualEntryMerchant = parsed.merchant;
    });
  }
```

Add `import 'dart:async';` at the very top of `main.dart` for
`StreamSubscription` (it isn't imported yet — check first; if it's
already there from a prior task, don't duplicate it).

Finally, update `_buildHome()` to hand the pending value to `RootShell`
exactly once, only once we're actually about to return it (not while
still locked or on the backup prompt):

```dart
  Widget _buildHome() {
    if (_supported == null || _showBackupPrompt == null) {
      return const SizedBox.shrink();
    }
    if (_showBackupPrompt == true) {
      return BackupPromptScreen(
        accountLinkService: widget.accountLinkService,
        onDone: () => setState(() => _showBackupPrompt = false),
      );
    }
    final pendingAmount = _pendingManualEntryAmount;
    final pendingMerchant = _pendingManualEntryMerchant;
    if (pendingAmount != null || pendingMerchant != null) {
      // Clear right away so a later rebuild (e.g. backgrounding then
      // resuming) doesn't hand the same pending value to a fresh
      // RootShell a second time.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _pendingManualEntryAmount = null;
            _pendingManualEntryMerchant = null;
          });
        }
      });
    }
    return RootShell(
      categoryRepository: widget.categoryRepository,
      transactionRepository: widget.transactionRepository,
      budgetRepository: widget.budgetRepository,
      accountLinkService: widget.accountLinkService,
      themeModeNotifier: widget.themeModeNotifier,
      currencyNotifier: widget.currencyNotifier,
      lockEnabledNotifier: widget.lockEnabledNotifier,
      lockSupported: _supported == true,
      localPrefs: widget.localPrefs,
      textRecognitionService: widget.textRecognitionService,
      notificationService: widget.notificationService,
      initialManualEntryAmount: pendingAmount,
      initialManualEntryMerchant: pendingMerchant,
    );
  }
```

Add the import for `parseDeepLink`:

```dart
import 'util/deep_link.dart';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS (all tests in the file, including the new one).

- [ ] **Step 5: Run full analyze/test and commit**

Run: `flutter analyze && flutter test`
Expected: both clean.

```bash
git add app/lib/main.dart app/test/widget_test.dart
git commit -m "feat: StubApp listens for incoming deep links and hands one pending log-expense to RootShell

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Real `AppLinksDeepLinkService`

**Files:**
- Modify: `app/pubspec.yaml` (via `flutter pub add app_links` — do not
  hand-edit the version)
- Create: `app/lib/data/app_links_deep_link_service.dart`
- Modify: `app/lib/main.dart` (delete `_PlaceholderDeepLinkService`,
  update its one call site)

**Interfaces:**
- Consumes: `DeepLinkService` (Task 2).
- Produces: `class AppLinksDeepLinkService implements DeepLinkService`.

- [ ] **Step 1: Add the dependency**

Run (from `app/`): `flutter pub add app_links`

- [ ] **Step 2: Verify the installed package's actual API before writing
      against it**

The `app_links` package's exact method names have changed across
versions (e.g. `getInitialLink` vs `getInitialAppLink`,
`getInitialAppLinkString`). **Do not guess from memory** — after Step 1,
read the installed version's public API directly:

```bash
find ~/.pub-cache/hosted/pub.dev -maxdepth 1 -iname "app_links-*"
```

then read that directory's `lib/src/app_links.dart` (or equivalent) to
confirm the real method/getter names for "the link that cold-launched the
app" and "a stream of links received while running." Use whatever those
are actually called in the installed version — the sketch below uses
placeholder names to fix, not to copy verbatim:

```dart
// app/lib/data/app_links_deep_link_service.dart
import 'package:app_links/app_links.dart';
import 'deep_link_service.dart';

/// Real `DeepLinkService` via the `app_links` package. No automated test —
/// needs a real platform channel, same story as
/// `MlKitTextRecognitionService`/`LocalAuthDeviceAuthService`/
/// `LocalNotificationsService` elsewhere in this app; verify manually.
class AppLinksDeepLinkService implements DeepLinkService {
  final _appLinks = AppLinks();

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink(); // verify against installed API — see Step 2

  @override
  Stream<Uri> get onLink => _appLinks.uriLinkStream; // verify against installed API — see Step 2
}
```

- [ ] **Step 3: Wire it into `main.dart`, removing the placeholder**

Delete the `_PlaceholderDeepLinkService` class added in Task 5.

Add the import:

```dart
import 'data/app_links_deep_link_service.dart';
```

Change `_StartupGate`'s `StubApp(...)` call site's
`deepLinkService: _PlaceholderDeepLinkService(),` line to:

```dart
          deepLinkService: AppLinksDeepLinkService(),
```

- [ ] **Step 4: Run full analyze/test**

Run: `flutter analyze && flutter test`
Expected: both clean — no test exercises `AppLinksDeepLinkService`
directly (it needs a real platform channel), but everything else must
still pass since `_PlaceholderDeepLinkService` is gone.

- [ ] **Step 5: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/data/app_links_deep_link_service.dart app/lib/main.dart
git commit -m "feat: add real AppLinksDeepLinkService, wire it into main.dart

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: iOS `LogExpenseIntent` (native, manual verification only)

**Files:**
- Create: `app/ios/Runner/LogExpenseIntent.swift`

**Interfaces:**
- Consumes: nothing from Dart — this is pure native Swift that opens a
  URL the rest of this plan already handles.
- Produces: a Shortcuts-discoverable action named "Log Expense to Stub"
  (exact display string is your call at implementation time).

This task has no automated test — App Intents need a real device and the
real Shortcuts app to verify. **The exact App Intents API has shifted
across iOS 16/17/18 — verify the current protocol requirements against
Apple's current documentation before writing this file; do not rely on
possibly-stale training knowledge for the precise syntax.** The sketch
below communicates the *shape* of what's needed, not verbatim code to
paste:

- [ ] **Step 1: Research the current `AppIntent`/`AppShortcutsProvider`
      API**

Fetch/read Apple's current App Intents documentation (search for
"AppIntent protocol" and "AppShortcutsProvider") to confirm: the exact
protocol conformance required, how to declare a `@Parameter` for a
required `Double` and an optional `String`, and how `perform()` should
return its result while also opening a URL from within the app's own
process (`openAppWhenRun` or equivalent — confirm the current property
name).

- [ ] **Step 2: Write the intent**

Shape (verify exact syntax per Step 1 before finalizing):

```swift
// app/ios/Runner/LogExpenseIntent.swift
import AppIntents
import UIKit

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense to Stub"
    static var openAppWhenRun: Bool = true // confirm current property name

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Merchant")
    var merchant: String?

    func perform() async throws -> some IntentResult {
        var components = URLComponents()
        components.scheme = "com.stubapp.stub"
        components.host = "log-expense"
        var items = [URLQueryItem(name: "amount", value: String(amount))]
        if let merchant, !merchant.isEmpty {
            items.append(URLQueryItem(name: "merchant", value: merchant))
        }
        components.queryItems = items
        if let url = components.url {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

struct StubAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: ["Log an expense in \(.applicationName)"],
            shortTitle: "Log Expense",
            systemImageName: "dollarsign.circle"
        )
    }
}
```

- [ ] **Step 3: Confirm the file is picked up by the Xcode project**

New Swift files under `ios/Runner/` are normally auto-included via
Xcode's file-system-synchronized groups in a default Flutter project —
open `ios/Runner.xcworkspace` in Xcode and confirm
`LogExpenseIntent.swift` appears in the Runner target's compile sources
before relying on it. If it doesn't, add it to the target manually in
Xcode (right-click the group → Add Files to "Runner").

- [ ] **Step 4: Build and manually verify on a real device**

Run: `flutter run` on a physical iOS device (App Intents/Shortcuts don't
work reliably in the iOS Simulator for this kind of system integration).
In the Shortcuts app, confirm "Log Expense to Stub" appears as an
available action, build a simple automation around it (e.g. triggered by
opening Wallet), run it, and confirm Stub opens with `ManualEntryScreen`
pre-filled with the amount you entered.

- [ ] **Step 5: Commit**

```bash
git add app/ios/Runner/LogExpenseIntent.swift
git commit -m "feat: add LogExpenseIntent — Siri Shortcuts quick-log action

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Post-plan: update CLAUDE.md

After all 7 tasks are done and manually verified per Task 7's Step 4, add
file-map rows for every new file in this plan (`util/deep_link.dart`,
`data/deep_link_service.dart`, `data/app_links_deep_link_service.dart`,
`ios/Runner/LogExpenseIntent.swift`), update `ManualEntryScreen`'s and
`RootShell`'s existing rows to mention the new params, update the test
count, and add an Open Items entry noting: iOS-only (no Android
equivalent in this pass), and whether real-device verification (Task 7,
Step 4) actually happened — this is exactly the kind of "not verified on
a real device yet" caveat this file already tracks for
`MlKitTextRecognitionService`/`LocalAuthDeviceAuthService`/
`LocalNotificationsService`.
