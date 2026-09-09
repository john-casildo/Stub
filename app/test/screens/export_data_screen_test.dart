import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/screens/export_data_screen.dart';

void main() {
  testWidgets('Defaults to the most recent month and every category selected, then exports', (tester) async {
    ExportMonth? exportedMonth;
    Set<String>? exportedCategories;

    await tester.pumpWidget(MaterialApp(home: ExportDataScreen(
      transactions: [
        Transaction(
          id: 't1', categoryId: 'c1', merchant: 'Corner Market', amount: 10, category: 'Groceries',
          source: TransactionSource.manual, occurredAt: DateTime.now(),
        ),
      ],
      categoryNames: const ['Groceries', 'Transport'],
      onClose: () {},
      onExport: (month, categories) {
        exportedMonth = month;
        exportedCategories = categories;
      },
    )));

    await tester.tap(find.text('Export CSV'));
    await tester.pump();

    expect(exportedMonth, isNotNull);
    expect(exportedCategories, {'Groceries', 'Transport'});
  });

  testWidgets('Deselecting a category excludes it from the export', (tester) async {
    Set<String>? exportedCategories;

    await tester.pumpWidget(MaterialApp(home: ExportDataScreen(
      transactions: const [],
      categoryNames: const ['Groceries', 'Transport'],
      onClose: () {},
      onExport: (month, categories) => exportedCategories = categories,
    )));

    await tester.tap(find.text('Transport'));
    await tester.pump();
    await tester.tap(find.text('Export CSV'));
    await tester.pump();

    expect(exportedCategories, {'Groceries'});
  });

  testWidgets('Export CSV is disabled once every category is deselected', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ExportDataScreen(
      transactions: const [],
      categoryNames: const ['Groceries'],
      onClose: () {},
      onExport: (month, categories) {},
    )));

    await tester.tap(find.text('Groceries'));
    await tester.pump();

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('With no transactions, defaults to "All time" (no months to pick from)', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ExportDataScreen(
      transactions: const [],
      categoryNames: const ['Groceries'],
      onClose: () {},
      onExport: (month, categories) {},
    )));

    expect(find.text('All time'), findsOneWidget);
  });
}
