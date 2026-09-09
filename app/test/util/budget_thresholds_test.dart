import 'package:flutter_test/flutter_test.dart';
import 'package:stub/util/budget_thresholds.dart';

void main() {
  group('highestNewlyCrossedThreshold', () {
    test('returns null below the first threshold', () {
      expect(highestNewlyCrossedThreshold(0.5, null), isNull);
    });

    test('returns the first crossed threshold when none notified yet', () {
      expect(highestNewlyCrossedThreshold(0.85, null), 0.80);
      expect(highestNewlyCrossedThreshold(0.90, null), 0.90);
    });

    test('a transaction that jumps straight past several tiers fires only the highest', () {
      expect(highestNewlyCrossedThreshold(1.10, null), 1.05);
    });

    test('returns null once the current tier is already notified', () {
      expect(highestNewlyCrossedThreshold(0.92, 0.90), isNull);
    });

    test('returns the next tier once crossed, even if a lower one was already notified', () {
      expect(highestNewlyCrossedThreshold(0.97, 0.90), 0.97);
    });

    test('caps out at the highest defined threshold', () {
      expect(highestNewlyCrossedThreshold(2.0, null), 1.05);
      expect(highestNewlyCrossedThreshold(2.0, 1.05), isNull);
    });
  });

  test('budgetThresholdMessage formats the category name and percentage', () {
    expect(budgetThresholdMessage('Groceries', 0.90), 'Groceries is at 90% of its budget.');
    expect(budgetThresholdMessage('Groceries', 1.05), 'Groceries is at 105% of its budget.');
  });
}
