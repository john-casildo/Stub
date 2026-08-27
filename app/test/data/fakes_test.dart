import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/models/budget_limit.dart';

void main() {
  test('FakeCategoryRepository creates, lists, and deletes in memory', () async {
    final repo = FakeCategoryRepository();
    final created = await repo.create('Groceries');
    expect((await repo.list()).map((c) => c.name), contains('Groceries'));

    await repo.delete(created.id);
    expect(await repo.list(), isEmpty);
  });

  test('FakeTransactionRepository creates, lists, updates, and deletes in memory', () async {
    final repo = FakeTransactionRepository();
    final t = await repo.create(FakeTransactionRepository.sample(categoryId: 'c1', merchant: 'Corner Market'));
    expect((await repo.list()).map((t) => t.merchant), contains('Corner Market'));

    await repo.update(t.copyWith(merchant: 'Corner Market 2'));
    expect((await repo.list()).first.merchant, 'Corner Market 2');

    await repo.delete(t.id);
    expect(await repo.list(), isEmpty);
  });

  test('FakeBudgetRepository creates and lists in memory', () async {
    final repo = FakeBudgetRepository();
    await repo.create(
      categoryId: 'c1',
      limitAmount: 300,
      periodType: BudgetPeriodType.monthly,
      periodStart: DateTime(2026, 8, 1),
    );
    expect((await repo.list()).first.limit, 300);
  });
}
