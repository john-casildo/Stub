import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stub/data/category_repository.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/data/local_prefs.dart';
import 'package:stub/data/transaction_repository.dart';
import 'package:stub/models/budget_limit.dart';
import 'package:stub/models/category.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/screens/root_shell.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RootShell starts on the ledger and switches to budgets on tab tap', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('LEFT TO SPEND'), findsOneWidget);

    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();
    expect(find.text('BUDGETED THIS MONTH'), findsOneWidget);
  });

  testWidgets('Profile tab shows the real ProfileScreen, not Ledger content', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Anonymous — not backed up'), findsOneWidget);
    expect(find.text('LEFT TO SPEND'), findsNothing); // no longer falling back to Ledger
    final nav = tester.widget<StubBottomNav>(find.byType(StubBottomNav));
    expect(nav.activeIndex, 2);
  });

  testWidgets('Tapping Settings from Profile opens SettingsScreen', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('THEME'), findsOneWidget);
  });

  testWidgets('Deleting all data from Settings clears transactions and categories', (tester) async {
    final categories = FakeCategoryRepository();
    final groceries = await categories.create('Groceries');
    final transactions = FakeTransactionRepository([
      FakeTransactionRepository.sample(categoryId: groceries.id, merchant: 'Corner Market', amount: 18.42),
    ]);
    final budgets = FakeBudgetRepository(null, categories);
    await budgets.create(categoryId: groceries.id, limitAmount: 300, periodType: BudgetPeriodType.monthly, periodStart: DateTime.now());

    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: categories,
      transactionRepository: transactions,
      budgetRepository: budgets,
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();

    // Back on Profile (settings popped), and the data is gone.
    expect(find.text('THEME'), findsNothing);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Corner Market'), findsNothing);
  });

  testWidgets('Delete-all loops list() until empty, deleting transactions beyond a single page', (tester) async {
    final categories = FakeCategoryRepository();
    final groceries = await categories.create('Groceries');
    // Seed more transactions than a single "page" to prove the delete-all
    // loop re-lists rather than relying on the snapshot loaded at open time.
    final transactions = _PagedFakeTransactionRepository(
      List.generate(
        5,
        (i) => FakeTransactionRepository.sample(categoryId: groceries.id, merchant: 'Merchant $i', amount: 1),
      ),
      pageSize: 2,
    );
    final budgets = FakeBudgetRepository(null, categories);
    await budgets.create(categoryId: groceries.id, limitAmount: 300, periodType: BudgetPeriodType.monthly, periodStart: DateTime.now());

    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: categories,
      transactionRepository: transactions,
      budgetRepository: budgets,
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();

    // All 5 transactions gone, even though the repository only ever
    // returns 2 per `list()` call — proves the delete loop kept going
    // rather than stopping after one pass.
    expect(await transactions.list(), isEmpty);
  });

  testWidgets('Delete-all shows a non-dismissible blocking indicator while in flight', (tester) async {
    final categories = FakeCategoryRepository();
    final groceries = await categories.create('Groceries');
    final transactions = _SlowFakeTransactionRepository([
      FakeTransactionRepository.sample(categoryId: groceries.id, merchant: 'Corner Market'),
    ]);
    final budgets = FakeBudgetRepository(null, categories);
    await budgets.create(categoryId: groceries.id, limitAmount: 300, periodType: BudgetPeriodType.monthly, periodStart: DateTime.now());

    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: categories,
      transactionRepository: transactions,
      budgetRepository: budgets,
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete everything'));
    // Let the confirm dialog's pop() resolve, run `_deleteAllData`
    // (which pushes the loading dialog), and let that dialog's own push
    // transition finish. The delete itself is still stuck on the gate,
    // so this can't be `pumpAndSettle` (the indeterminate progress
    // indicator's animation never settles).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Blocking dialog is up, and Settings' own close (X) button is no
    // longer reachable through it (the dialog's barrier absorbs taps).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing); // confirm dialog already dismissed
    expect(find.text('THEME'), findsOneWidget); // Settings is still the route underneath

    await transactions.releaseAll();
    await tester.pumpAndSettle();

    // Dialog gone, Settings popped back to Profile, delete completed.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('THEME'), findsNothing);
  });

  testWidgets('A failed export shows a friendly message instead of failing silently', (tester) async {
    // `exportTransactionsCsv` calls path_provider's platform channel to
    // find a temp directory; mock it to fail, exercising the same
    // failure path a real file-system/plugin error would take in
    // production, without depending on real OS-level plugin behavior.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (call) async => throw PlatformException(code: 'error', message: 'no temp directory'),
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null));

    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export data'));
    await tester.pumpAndSettle();

    expect(find.text('Could not export data. Please try again.'), findsOneWidget);
  });

  testWidgets('Switching tabs cross-fades cleanly and settles on the new screen only', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();

    expect(find.text('BUDGETED THIS MONTH'), findsOneWidget);
    expect(find.text('LEFT TO SPEND'), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('LEFT TO SPEND'), findsOneWidget);
    expect(find.text('BUDGETED THIS MONTH'), findsNothing);
  });

  testWidgets('RootShell loads real data from its repositories and shows it', (tester) async {
    final categories = FakeCategoryRepository();
    final groceries = await categories.create('Groceries');

    final transactions = FakeTransactionRepository([
      FakeTransactionRepository.sample(categoryId: groceries.id, merchant: 'Corner Market', amount: 18.42),
    ]);

    final budgets = FakeBudgetRepository(null, categories);
    await budgets.create(
      categoryId: groceries.id,
      limitAmount: 300,
      periodType: BudgetPeriodType.monthly,
      periodStart: DateTime.now(),
    );

    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: categories,
      transactionRepository: transactions,
      budgetRepository: budgets,
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Corner Market'), findsOneWidget);
  });

  testWidgets('RootShell shows a loading state, then an error state, on a failing repository', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: _FailingCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));

    // Loading state visible on the very first frame, before the failing future resolves.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.textContaining('Something went wrong'), findsOneWidget);
  });

  testWidgets('Deleting a category with no transactions removes it from Budgets', (tester) async {
    final categories = FakeCategoryRepository();
    final groceries = await categories.create('Groceries');
    final budgets = FakeBudgetRepository(null, categories);
    await budgets.create(categoryId: groceries.id, limitAmount: 300, periodType: BudgetPeriodType.monthly, periodStart: DateTime.now());

    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: categories,
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: budgets,
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('delete-category-${groceries.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsNothing);
  });

  testWidgets('Tapping Manual Entry FAB with zero categories shows a snackbar and does not push ManualEntryScreen', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ledger-add-manual-entry')));
    await tester.pumpAndSettle();

    expect(find.text('Add a category first, then log an expense.'), findsOneWidget);
    expect(find.text('tap to type an amount'), findsNothing);
  });

  testWidgets('A failed write shows a friendly message and leaves the modal open', (tester) async {
    final categories = FakeCategoryRepository();
    await categories.create('Groceries');

    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: categories,
      transactionRepository: _FailingCreateTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ledger-add-manual-entry')));
    await tester.pumpAndSettle();

    // Manual entry pushed successfully — zero-category guard didn't fire.
    expect(find.text('tap to type an amount'), findsOneWidget);

    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    expect(find.textContaining('A category with that name already exists.'), findsOneWidget);
    // The modal stayed open — the write failed, so onSuccess (which pops) never ran.
    expect(find.text('tap to type an amount'), findsOneWidget);
  });

  testWidgets('Deleting a category with existing transactions shows a blocked-delete message', (tester) async {
    final categories = FakeCategoryRepository();
    final groceries = await categories.create('Groceries');
    final transactions = FakeTransactionRepository([
      FakeTransactionRepository.sample(categoryId: groceries.id, merchant: 'Corner Market'),
    ]);
    final budgets = FakeBudgetRepository(null, categories);
    await budgets.create(categoryId: groceries.id, limitAmount: 300, periodType: BudgetPeriodType.monthly, periodStart: DateTime.now());

    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: _RestrictingCategoryRepository(categories, transactions),
      transactionRepository: transactions,
      budgetRepository: budgets,
      accountLinkService: FakeAccountLinkService(),
      themeModeNotifier: ValueNotifier(ThemeMode.system),
      localPrefs: LocalPrefs(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('delete-category-${groceries.id}')));
    await tester.pumpAndSettle();

    expect(find.textContaining("Can't delete a category with existing transactions"), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget); // still there — delete was blocked
  });
}

/// Always fails `list()` — exercises RootShell's error state without
/// needing a real failing backend.
class _FailingCategoryRepository implements CategoryRepository {
  @override
  Future<List<Category>> list() async => throw Exception('boom');

  @override
  Future<Category> create(String name) async => throw UnimplementedError();

  @override
  Future<void> delete(String id) async => throw UnimplementedError();
}

/// Wraps a real `FakeCategoryRepository`, delegating everything except
/// `delete`, which throws the same `PostgrestException` (code `23503`)
/// Postgres raises for the `ON DELETE RESTRICT` rule whenever the
/// wrapped `FakeTransactionRepository` still has a transaction pointing
/// at that category — this exercises `RootShell._deleteCategory`'s catch
/// branch without needing the schema's real foreign-key constraint.
class _RestrictingCategoryRepository implements CategoryRepository {
  _RestrictingCategoryRepository(this._categories, this._transactions);
  final FakeCategoryRepository _categories;
  final FakeTransactionRepository _transactions;

  @override
  Future<List<Category>> list() => _categories.list();

  @override
  Future<Category> create(String name) => _categories.create(name);

  @override
  Future<void> delete(String id) async {
    final transactions = await _transactions.list();
    if (transactions.any((t) => t.categoryId == id)) {
      throw PostgrestException(code: '23503', message: 'update or delete on table "categories" violates foreign key constraint');
    }
    await _categories.delete(id);
  }
}

/// Mimics PostgREST's `max_rows` cap: `list()` only ever returns up to
/// [pageSize] items at a time (whatever remains after prior deletes), so a
/// caller that stops after a single `list()`/delete pass will always leave
/// items behind. Used to prove `RootShell._deleteAllData` loops until
/// `list()` comes back empty rather than trusting one snapshot.
class _PagedFakeTransactionRepository implements TransactionRepository {
  _PagedFakeTransactionRepository(List<Transaction> seed, {required this.pageSize}) : _items = List.of(seed);
  final List<Transaction> _items;
  final int pageSize;

  @override
  Future<List<Transaction>> list() async => List.unmodifiable(_items.take(pageSize));

  @override
  Future<Transaction> create(Transaction transaction) async {
    _items.add(transaction);
    return transaction;
  }

  @override
  Future<void> update(Transaction transaction) async {
    final index = _items.indexWhere((t) => t.id == transaction.id);
    if (index != -1) _items[index] = transaction;
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((t) => t.id == id);
}

/// Delays every `delete()` until the test explicitly calls [releaseAll],
/// so a test can assert on UI state (e.g. a blocking dialog) while a
/// delete-all operation is still in flight.
class _SlowFakeTransactionRepository implements TransactionRepository {
  _SlowFakeTransactionRepository(List<Transaction> seed) : _items = List.of(seed);
  final List<Transaction> _items;
  final _gate = Completer<void>();

  Future<void> releaseAll() async {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<List<Transaction>> list() async => List.unmodifiable(_items);

  @override
  Future<Transaction> create(Transaction transaction) async {
    _items.add(transaction);
    return transaction;
  }

  @override
  Future<void> update(Transaction transaction) async {
    final index = _items.indexWhere((t) => t.id == transaction.id);
    if (index != -1) _items[index] = transaction;
  }

  @override
  Future<void> delete(String id) async {
    await _gate.future;
    _items.removeWhere((t) => t.id == id);
  }
}

/// Always fails `create()` with a `23505` (unique-violation) `PostgrestException`
/// — exercises `RootShell._guardedWrite`'s failure path (friendly message shown,
/// modal stays open) without needing a real failing backend.
class _FailingCreateTransactionRepository implements TransactionRepository {
  @override
  Future<List<Transaction>> list() async => const [];

  @override
  Future<Transaction> create(Transaction transaction) async =>
      throw PostgrestException(code: '23505', message: 'duplicate key value violates unique constraint');

  @override
  Future<void> update(Transaction transaction) async => throw UnimplementedError();

  @override
  Future<void> delete(String id) async => throw UnimplementedError();
}
