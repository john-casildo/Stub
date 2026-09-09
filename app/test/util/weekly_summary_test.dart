import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/util/weekly_summary.dart';

Transaction _t({required String category, required double amount}) => Transaction(
      id: 't',
      categoryId: 'c',
      merchant: 'M',
      amount: amount,
      category: category,
      source: TransactionSource.manual,
      occurredAt: DateTime.now(),
    );

void main() {
  test('computeWeeklySummary returns null for an empty week', () {
    expect(computeWeeklySummary([]), isNull);
  });

  test('computeWeeklySummary totals spend and finds the top category', () {
    final summary = computeWeeklySummary([
      _t(category: 'Groceries', amount: 40),
      _t(category: 'Groceries', amount: 30),
      _t(category: 'Transport', amount: 20),
    ])!;

    expect(summary.total, 90);
    expect(summary.topCategory, 'Groceries');
    expect(summary.topCategoryAmount, 70);
  });

  test('weeklySummaryMessage includes the total and top category', () {
    const summary = WeeklySummary(total: 342, topCategory: 'Groceries', topCategoryAmount: 118);
    expect(
      weeklySummaryMessage(summary),
      r'You spent $342.00 this week. Groceries was your biggest category at $118.00.',
    );
  });

  test('weeklySummaryMessage falls back to just the total when there is no top category', () {
    const summary = WeeklySummary(total: 50);
    expect(weeklySummaryMessage(summary), r'You spent $50.00 this week.');
  });
}
