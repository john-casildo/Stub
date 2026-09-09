import 'dart:async';
import 'dart:math';
import 'account_link_service.dart';
import 'budget_repository.dart';
import 'category_repository.dart';
import 'device_auth_service.dart';
import 'notification_service.dart';
import 'text_recognition_service.dart';
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
  Future<Category> create(String name, {String? currencyCode, String icon = 'tag', int? colorIndex}) async {
    final category = Category(id: _fakeId(), name: name, currencyCode: currencyCode, icon: icon, colorIndex: colorIndex);
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
  Future<List<Transaction>> list({int offset = 0}) async => List.unmodifiable(_items.skip(offset));

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
    String icon = 'tag';
    int? colorIndex;
    if (_categories != null) {
      final match = (await _categories.list()).where((c) => c.id == categoryId);
      if (match.isNotEmpty) {
        name = match.first.name;
        icon = match.first.icon;
        colorIndex = match.first.colorIndex;
      }
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
      icon: icon,
      colorIndex: colorIndex,
    ));
  }
}

class FakeAccountLinkService implements AccountLinkService {
  FakeAccountLinkService({this.isAnonymous = true, this.linkedEmail, this.memberSince, this.firstName, this.lastName});
  @override
  bool isAnonymous;
  @override
  String? linkedEmail;
  @override
  DateTime? memberSince;
  @override
  String? firstName;
  @override
  String? lastName;

  final _controller = StreamController<bool>.broadcast();

  @override
  Future<void> linkEmail(String email) async {
    linkedEmail = email;
    isAnonymous = false;
    _controller.add(isAnonymous);
  }

  @override
  Future<void> setName({required String firstName, required String lastName}) async {
    this.firstName = firstName;
    this.lastName = lastName;
  }

  @override
  Stream<bool> get linkStatusChanges => _controller.stream;
}

class FakeDeviceAuthService implements DeviceAuthService {
  FakeDeviceAuthService({this.supported = true, this.succeeds = true});
  bool supported;
  bool succeeds;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate() async => succeeds;
}

class FakeTextRecognitionService implements TextRecognitionService {
  FakeTextRecognitionService({this.result = const []});
  List<RecognizedLine> result;

  @override
  Future<List<RecognizedLine>> recognizeText(String imagePath) async => result;
}

class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.permissionGranted = true});
  bool permissionGranted;
  bool permissionRequested = false;
  final List<({String title, String body})> shown = [];

  @override
  Future<bool> requestPermission() async {
    permissionRequested = true;
    return permissionGranted;
  }

  @override
  Future<void> show({required String title, required String body}) async {
    shown.add((title: title, body: body));
  }
}
