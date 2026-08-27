import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/budget_limit.dart';
import 'package:stub/models/category.dart';
import 'package:stub/models/transaction.dart';

void main() {
  test('Category maps to/from a Postgres row', () {
    final category = Category.fromRow({'id': 'c1', 'name': 'Groceries'});
    expect(category.id, 'c1');
    expect(category.name, 'Groceries');
    expect(category.toInsertRow('u1'), {'user_id': 'u1', 'name': 'Groceries'});
  });

  test('BudgetPeriodType round-trips through its wire value', () {
    expect(BudgetPeriodType.monthly.wireValue, 'monthly');
    expect(BudgetPeriodType.fromWireValue('custom'), BudgetPeriodType.custom);
  });

  test('BudgetLimit.fromRow reads a budget_progress view row', () {
    final budget = BudgetLimit.fromRow({
      'budget_id': 'b1',
      'category_id': 'c1',
      'category_name': 'Groceries',
      'limit_amount': '300.00',
      'period_type': 'monthly',
      'period_start': '2026-08-01',
      'period_end': null,
      'spent': '212.40',
    });
    expect(budget.id, 'b1');
    expect(budget.categoryId, 'c1');
    expect(budget.name, 'Groceries');
    expect(budget.limit, 300.0);
    expect(budget.spent, 212.40);
    expect(budget.periodType, BudgetPeriodType.monthly);
    expect(budget.periodEnd, isNull);
  });

  test('Transaction.dateLabel is computed from occurredAt', () {
    final today = DateTime.now();
    final t = Transaction(
      id: 't1',
      categoryId: 'c1',
      merchant: 'Corner Market',
      amount: 18.42,
      category: 'Groceries',
      source: TransactionSource.receipt,
      occurredAt: today,
    );
    expect(t.dateLabel, 'Today');
  });

  test('Transaction maps to/from a Postgres row', () {
    final row = {
      'id': 't1',
      'category_id': 'c1',
      'merchant': 'Corner Market',
      'amount': '18.42',
      'source': 'receipt',
      'occurred_at': '2026-08-25T10:00:00.000Z',
    };
    final t = Transaction.fromRow(row, categoryName: 'Groceries');
    expect(t.id, 't1');
    expect(t.merchant, 'Corner Market');
    expect(t.amount, 18.42);
    expect(t.source, TransactionSource.receipt);

    final insertRow = t.toInsertRow(userId: 'u1');
    expect(insertRow['user_id'], 'u1');
    expect(insertRow['category_id'], 'c1');
    expect(insertRow['merchant'], 'Corner Market');
    expect(insertRow['amount'], 18.42);
    expect(insertRow['source'], 'receipt');
  });

  test('BudgetLimit computes fraction and warning state', () {
    final onTrack = BudgetLimit(
      id: 'b1',
      categoryId: 'c1',
      name: 'Groceries',
      spent: 212,
      limit: 300,
      periodType: BudgetPeriodType.monthly,
      periodStart: DateTime(2026, 8, 1),
    );
    expect(onTrack.fraction, closeTo(0.7067, 0.001));
    expect(onTrack.isWarning, isFalse);

    final overBudget = BudgetLimit(
      id: 'b2',
      categoryId: 'c2',
      name: 'Dining out',
      spent: 96,
      limit: 100,
      periodType: BudgetPeriodType.monthly,
      periodStart: DateTime(2026, 8, 1),
    );
    expect(overBudget.isWarning, isTrue);
  });
}
