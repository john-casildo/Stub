import 'dart:async';
import 'dart:io';

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
const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

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

  testWidgets('Export data collects transactions beyond a single page, not just the first page', (tester) async {
    // Real temp dir so `exportTransactionsCsv`'s file write and share_plus's
    // "file already has a real path" fast path both succeed for real,
    // letting us read back the CSV that was actually written. Real
    // `dart:io` calls like this one need `runAsync` inside a `testWidgets`
    // body — see the comment further down, by the export tap, for why.
    late Directory tempDir;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('stub_export_test');
    });
    addTearDown(() => tempDir.delete(recursive: true));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _pathProviderChannel,
      (call) async => tempDir.path,
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _shareChannel,
      (call) async => 'dev.fluttercommunity.plus/share/success',
    );
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null));

    final categories = FakeCategoryRepository();
    final groceries = await categories.create('Groceries');
    // Seed more transactions than a single "page" — mimics PostgREST's
    // `max_rows` cap (see `SupabaseTransactionRepository`) via an offset-aware
    // fake, so a caller that stops after the first `list()` call would
    // silently drop the rest.
    final transactions = _OffsetPagedFakeTransactionRepository(
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

    // `_exportData` does real `dart:io` work (temp file write, then
    // share_plus's own file copy) — under `testWidgets`' default fake-async
    // zone, real I/O like this never completes (nothing drives the real
    // event loop), so the tap that kicks it off has to run inside
    // `runAsync`, which switches to a real zone for its duration. See
    // `exportTransactionsCsv`/`_fetchAllTransactions` in `root_shell.dart`.
    await tester.runAsync(() async {
      await tester.tap(find.text('Export data'));
      // Give the fire-and-forget `_exportData()` future — kicked off by the
      // tap above but not awaited by the widget itself — a real chance to
      // run to completion before we move on to read its output.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    late String csvContent;
    await tester.runAsync(() async {
      csvContent = await File('${tempDir.path}/stub_transactions.csv').readAsString();
    });
    for (var i = 0; i < 5; i++) {
      expect(csvContent, contains('Merchant $i'), reason: 'Merchant $i missing — export truncated at the first page');
    }
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

  testWidgets('A delete-all failure partway through reloads so the UI reflects actually-remaining data', (tester) async {
    final categories = FakeCategoryRepository();
    final groceries = await categories.create('Groceries');
    // Three transactions; the repository below lets the first delete
    // succeed and throws on the second, so the delete loop stops with one
    // transaction gone and two still present — proving the error branch's
    // `_reload()` picks up that actual remainder instead of leaving the
    // stale pre-delete snapshot (all three) on screen.
    final transactions = _FailingAfterNDeletesTransactionRepository(
      [
        FakeTransactionRepository.sample(categoryId: groceries.id, merchant: 'First', amount: 1),
        FakeTransactionRepository.sample(categoryId: groceries.id, merchant: 'Second', amount: 1),
        FakeTransactionRepository.sample(categoryId: groceries.id, merchant: 'Third', amount: 1),
      ],
      failAt: 2,
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

    // Failure surfaced, and we're still on Settings (error branch doesn't
    // pop back to Profile the way the success branch does).
    expect(find.textContaining('Something went wrong'), findsOneWidget);
    expect(find.text('THEME'), findsOneWidget);

    // The snackbar is shown via the app-level `ScaffoldMessenger` (RootShell
    // itself has no `Scaffold`), so it floats above whatever tab is showing
    // and outlives the Settings route it was triggered from — let its
    // default ~4s auto-dismiss actually elapse before navigating further,
    // or it can still be sitting over the bottom nav and absorb later taps.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Settings' own close (X) button is the only IconButton on this screen.
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsNothing); // actually deleted
    expect(find.text('Second'), findsOneWidget); // delete failed on this one — still present
    expect(find.text('Third'), findsOneWidget); // never attempted — still present
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
  Future<List<Transaction>> list({int offset = 0}) async => List.unmodifiable(_items.take(pageSize));

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

/// Mimics real offset-based pagination (unlike `_PagedFakeTransactionRepository`
/// above, which only works for a shrinking list): `list(offset: ...)` returns
/// up to [pageSize] items starting at `offset`, with nothing ever removed.
/// Used to prove a read-only caller (CSV export) that pages by advancing
/// `offset` — rather than relying on deletion to reveal the next page —
/// collects every transaction, not just the first page.
class _OffsetPagedFakeTransactionRepository implements TransactionRepository {
  _OffsetPagedFakeTransactionRepository(List<Transaction> seed, {required this.pageSize}) : _items = List.of(seed);
  final List<Transaction> _items;
  final int pageSize;

  @override
  Future<List<Transaction>> list({int offset = 0}) async =>
      List.unmodifiable(_items.skip(offset).take(pageSize));

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
  Future<List<Transaction>> list({int offset = 0}) async => List.unmodifiable(_items);

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

/// Deletes normally but throws on the [failAt]-th call to `delete()`
/// (1-indexed) — lets a test drive `_deleteAllData`'s loop partway through
/// and then verify the UI reflects what's actually left afterward, not a
/// stale pre-delete snapshot.
class _FailingAfterNDeletesTransactionRepository implements TransactionRepository {
  _FailingAfterNDeletesTransactionRepository(List<Transaction> seed, {required this.failAt}) : _items = List.of(seed);
  final List<Transaction> _items;
  final int failAt;
  int _deleteCount = 0;

  @override
  Future<List<Transaction>> list({int offset = 0}) async => List.unmodifiable(_items.skip(offset));

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
    _deleteCount++;
    if (_deleteCount == failAt) {
      throw Exception('boom');
    }
    _items.removeWhere((t) => t.id == id);
  }
}

/// Always fails `create()` with a `23505` (unique-violation) `PostgrestException`
/// — exercises `RootShell._guardedWrite`'s failure path (friendly message shown,
/// modal stays open) without needing a real failing backend.
class _FailingCreateTransactionRepository implements TransactionRepository {
  @override
  Future<List<Transaction>> list({int offset = 0}) async => const [];

  @override
  Future<Transaction> create(Transaction transaction) async =>
      throw PostgrestException(code: '23505', message: 'duplicate key value violates unique constraint');

  @override
  Future<void> update(Transaction transaction) async => throw UnimplementedError();

  @override
  Future<void> delete(String id) async => throw UnimplementedError();
}
