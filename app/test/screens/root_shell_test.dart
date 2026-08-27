import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stub/data/category_repository.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/data/transaction_repository.dart';
import 'package:stub/models/budget_limit.dart';
import 'package:stub/models/category.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/screens/root_shell.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';

void main() {
  testWidgets('RootShell starts on the ledger and switches to budgets on tab tap', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('LEFT TO SPEND'), findsOneWidget);

    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();
    expect(find.text('BUDGETED THIS MONTH'), findsOneWidget);
  });

  testWidgets('Profile tab shows Ledger content with the nav bar highlighting Home, not Profile', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('LEFT TO SPEND'), findsOneWidget);
    final nav = tester.widget<StubBottomNav>(find.byType(StubBottomNav));
    expect(nav.activeIndex, 0);
  });

  testWidgets('Switching tabs cross-fades cleanly and settles on the new screen only', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
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
    )));
    await tester.pumpAndSettle();

    expect(find.text('Corner Market'), findsOneWidget);
  });

  testWidgets('RootShell shows a loading state, then an error state, on a failing repository', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RootShell(
      categoryRepository: _FailingCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
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
