import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/util/csv_export.dart';

void main() {
  test('buildTransactionsCsv produces a header row plus one row per transaction', () {
    final transactions = [
      Transaction(
        id: 't1',
        categoryId: 'c1',
        merchant: 'Corner Market',
        amount: 18.42,
        category: 'Groceries',
        source: TransactionSource.receipt,
        occurredAt: DateTime(2026, 8, 25),
      ),
    ];

    final csv = buildTransactionsCsv(transactions);
    final lines = csv.trim().split('\n');

    expect(lines[0], 'Date,Merchant,Amount,Category,Source');
    expect(lines[1], contains('Corner Market'));
    expect(lines[1], contains('18.42'));
    expect(lines[1], contains('Groceries'));
  });

  test('buildTransactionsCsv escapes a comma in a merchant name', () {
    final transactions = [
      Transaction(
        id: 't1',
        categoryId: 'c1',
        merchant: 'Smith, Jones & Co',
        amount: 10,
        category: 'Groceries',
        source: TransactionSource.manual,
        occurredAt: DateTime(2026, 8, 25),
      ),
    ];

    final csv = buildTransactionsCsv(transactions);
    expect(csv, contains('"Smith, Jones & Co"'));
  });
}
