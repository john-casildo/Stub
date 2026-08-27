import 'dart:math';
import 'budget_repository.dart';
import 'category_repository.dart';
import 'transaction_repository.dart';
import '../models/budget_limit.dart';
import '../models/category.dart';
import '../models/transaction.dart';

String _fakeId() => Random().nextInt(1 << 32).toRadixString(16);

class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository([List<Category>? seed]) : _items = List.of(seed ?? const []);
  final List<Category> _items;

  @override
  Future<List<Category>> list() async => List.unmodifiable(_items);

  @override
  Future<Category> create(String name) async {
    final category = Category(id: _fakeId(), name: name);
    _items.add(category);
    return category;
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((c) => c.id == id);
}

class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository([List<Transaction>? seed]) : _items = List.of(seed ?? const []);
  final List<Transaction> _items;

  static Transaction sample({required String categoryId, required String merchant, double amount = 10}) => Transaction(
        id: _fakeId(),
        categoryId: categoryId,
        merchant: merchant,
        amount: amount,
        category: 'Category',
        source: TransactionSource.manual,
        occurredAt: DateTime.now(),
      );

  @override
  Future<List<Transaction>> list() async => List.unmodifiable(_items);

  @override
  Future<Transaction> create(Transaction transaction) async {
    final withId = transaction.copyWith();
    _items.add(withId);
    return withId;
  }

  @override
  Future<void> update(Transaction transaction) async {
    final index = _items.indexWhere((t) => t.id == transaction.id);
    if (index != -1) _items[index] = transaction;
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((t) => t.id == id);
}

class FakeBudgetRepository implements BudgetRepository {
  FakeBudgetRepository([List<BudgetLimit>? seed]) : _items = List.of(seed ?? const []);
  final List<BudgetLimit> _items;

  @override
  Future<List<BudgetLimit>> list() async => List.unmodifiable(_items);

  @override
  Future<void> create({
    required String categoryId,
    required double limitAmount,
    required BudgetPeriodType periodType,
    required DateTime periodStart,
    DateTime? periodEnd,
  }) async {
    _items.add(BudgetLimit(
      id: _fakeId(),
      categoryId: categoryId,
      name: 'Category',
      spent: 0,
      limit: limitAmount,
      periodType: periodType,
      periodStart: periodStart,
      periodEnd: periodEnd,
    ));
  }
}
