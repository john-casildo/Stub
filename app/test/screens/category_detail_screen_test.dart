import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/screens/category_detail_screen.dart';
import 'package:stub/widgets/stub_progress_ring.dart';

void main() {
  testWidgets('Shows the category name and its transactions', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CategoryDetailScreen(
      categoryName: 'Dining',
      icon: 'tag',
      color: Colors.blue,
      transactions: [
        Transaction(
          id: 't1',
          categoryId: 'c1',
          merchant: 'Corner Market',
          amount: 12.50,
          category: 'Dining',
          source: TransactionSource.receipt,
          occurredAt: DateTime.now(),
        ),
      ],
      onClose: () {},
    )));

    expect(find.text('Dining'), findsOneWidget);
    expect(find.text('Corner Market'), findsOneWidget);
  });

  testWidgets('Shows an empty state when the category has no transactions', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CategoryDetailScreen(
      categoryName: 'Dining',
      icon: 'tag',
      color: Colors.blue,
      transactions: const [],
      onClose: () {},
    )));

    expect(find.textContaining('No transactions'), findsOneWidget);
  });

  testWidgets('Tapping a transaction calls onTransactionTap', (tester) async {
    Transaction? tapped;
    final transaction = Transaction(
      id: 't1',
      categoryId: 'c1',
      merchant: 'Corner Market',
      amount: 12.50,
      category: 'Dining',
      source: TransactionSource.receipt,
      occurredAt: DateTime.now(),
    );
    await tester.pumpWidget(MaterialApp(home: CategoryDetailScreen(
      categoryName: 'Dining',
      icon: 'tag',
      color: Colors.blue,
      transactions: [transaction],
      onClose: () {},
      onTransactionTap: (t) => tapped = t,
    )));

    await tester.tap(find.text('Corner Market'));
    expect(tapped, transaction);
  });

  testWidgets('Shows a hero total (in the category\'s own currency) and a progress ring when it has a budget', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CategoryDetailScreen(
      categoryName: 'Dining',
      icon: 'tag',
      color: Colors.blue,
      transactions: [
        Transaction(id: 't1', categoryId: 'c1', merchant: 'A', amount: 100, category: 'Dining', source: TransactionSource.receipt, occurredAt: DateTime.now()),
        Transaction(id: 't2', categoryId: 'c1', merchant: 'B', amount: 42, category: 'Dining', source: TransactionSource.receipt, occurredAt: DateTime.now()),
      ],
      onClose: () {},
      fraction: 0.71,
      currencyCode: 'CRC',
    )));

    expect(find.text('₡142.00'), findsOneWidget);
    expect(find.byType(StubProgressRing), findsOneWidget);
  });

  testWidgets('Shows the established limit alongside the total when the category has a budget', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CategoryDetailScreen(
      categoryName: 'Dining',
      icon: 'tag',
      color: Colors.blue,
      transactions: [
        Transaction(id: 't1', categoryId: 'c1', merchant: 'A', amount: 100, category: 'Dining', source: TransactionSource.receipt, occurredAt: DateTime.now()),
      ],
      onClose: () {},
      fraction: 0.5,
      limit: 200,
    )));

    expect(find.textContaining('200.00 limit'), findsOneWidget);
  });

  testWidgets('Omits the limit line when the category has no budget', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CategoryDetailScreen(
      categoryName: 'Dining',
      icon: 'tag',
      color: Colors.blue,
      transactions: [
        Transaction(id: 't1', categoryId: 'c1', merchant: 'A', amount: 100, category: 'Dining', source: TransactionSource.receipt, occurredAt: DateTime.now()),
      ],
      onClose: () {},
    )));

    expect(find.textContaining('limit'), findsNothing);
  });

  testWidgets('Omits the progress ring when the category has no budget', (tester) async {
    await tester.pumpWidget(MaterialApp(home: CategoryDetailScreen(
      categoryName: 'Dining',
      icon: 'tag',
      color: Colors.blue,
      transactions: [
        Transaction(id: 't1', categoryId: 'c1', merchant: 'A', amount: 100, category: 'Dining', source: TransactionSource.receipt, occurredAt: DateTime.now()),
      ],
      onClose: () {},
    )));

    expect(find.byType(StubProgressRing), findsNothing);
  });

  testWidgets('Tapping close calls onClose', (tester) async {
    var closed = false;
    await tester.pumpWidget(MaterialApp(home: CategoryDetailScreen(
      categoryName: 'Dining',
      icon: 'tag',
      color: Colors.blue,
      transactions: const [],
      onClose: () => closed = true,
    )));

    await tester.tap(find.byType(IconButton));
    expect(closed, isTrue);
  });
}
