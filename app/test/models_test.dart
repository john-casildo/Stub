import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/budget_limit.dart';

void main() {
  test('BudgetLimit computes fraction and warning state', () {
    const onTrack = BudgetLimit(name: 'Groceries', spent: 212, limit: 300);
    expect(onTrack.fraction, closeTo(0.7067, 0.001));
    expect(onTrack.isWarning, isFalse);

    const overBudget = BudgetLimit(name: 'Dining out', spent: 96, limit: 100);
    expect(overBudget.isWarning, isTrue);
  });
}
