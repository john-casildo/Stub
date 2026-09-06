import 'dart:async';
import 'dart:math';
import 'account_link_service.dart';
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

/// [categories], when given, lets this fake mirror two things the real
/// `SupabaseBudgetRepository` gets for free from the schema: resolving a
/// real category name at `create()` time (the `budget_progress` view
/// always joins in the correct name), and dropping a budget from `list()`
/// once its category is gone (`budgets.category_id` is `ON DELETE
/// CASCADE`). Without it, both fall back to best-effort behavior (a
/// placeholder name; no cascade) — fine for tests that don't touch
/// category deletion.
class FakeBudgetRepository implements BudgetRepository {
  FakeBudgetRepository([List<BudgetLimit>? seed, this._categories]) : _items = List.of(seed ?? const []);
  final List<BudgetLimit> _items;
  final FakeCategoryRepository? _categories;

  @override
  Future<List<BudgetLimit>> list() async {
    if (_categories == null) return List.unmodifiable(_items);
    final liveCategoryIds = (await _categories.list()).map((c) => c.id).toSet();
    return List.unmodifiable(_items.where((b) => liveCategoryIds.contains(b.categoryId)));
  }

  @override
  Future<void> create({
    required String categoryId,
    required double limitAmount,
    required BudgetPeriodType periodType,
    required DateTime periodStart,
    DateTime? periodEnd,
  }) async {
    String name = 'Category';
    if (_categories != null) {
      final match = (await _categories.list()).where((c) => c.id == categoryId);
      if (match.isNotEmpty) name = match.first.name;
    }
    _items.add(BudgetLimit(
      id: _fakeId(),
      categoryId: categoryId,
      name: name,
      spent: 0,
      limit: limitAmount,
      periodType: periodType,
      periodStart: periodStart,
      periodEnd: periodEnd,
    ));
  }
}

class FakeAccountLinkService implements AccountLinkService {
  FakeAccountLinkService({this.isAnonymous = true, this.linkedEmail, this.memberSince});
  @override
  bool isAnonymous;
  @override
  String? linkedEmail;
  @override
  DateTime? memberSince;

  final _controller = StreamController<bool>.broadcast();

  @override
  Future<void> linkEmail(String email) async {
    linkedEmail = email;
    isAnonymous = false;
    _controller.add(isAnonymous);
  }

  @override
  Stream<bool> get linkStatusChanges => _controller.stream;
}
