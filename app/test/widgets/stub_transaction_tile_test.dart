// app/test/widgets/stub_transaction_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/widgets/stub_transaction_tile.dart';

void main() {
  testWidgets('StubTransactionTile shows merchant, source, and amount', (tester) async {
    final transaction = Transaction(
      id: 't1',
      categoryId: 'c1',
      merchant: 'Corner Market',
      amount: 18.42,
      category: 'Groceries',
      source: TransactionSource.receipt,
      occurredAt: DateTime.now(),
    );
    await tester.pumpWidget(
      MaterialApp(home: StubTransactionTile(transaction: transaction)),
    );
    expect(find.text('Corner Market'), findsOneWidget);
    expect(find.textContaining('RECEIPT'), findsOneWidget);
    expect(find.textContaining('18.42'), findsOneWidget);
  });
}
