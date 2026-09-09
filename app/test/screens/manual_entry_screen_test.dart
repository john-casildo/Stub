import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/manual_entry_screen.dart';

void main() {
  testWidgets('ManualEntryScreen saves the entered amount and category', (tester) async {
    double? savedAmount;
    String? savedCategory;
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const ['Groceries', 'Dining', 'Transport'],
          onClose: () {},
          onSave: (amount, merchant, category) {
            savedAmount = amount;
            savedCategory = category;
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '12.50');
    await tester.tap(find.text('Dining'));
    await tester.pump();
    await tester.tap(find.text('Save entry'));

    expect(savedAmount, 12.50);
    expect(savedCategory, 'Dining');
  });

  testWidgets('Amount field shows live thousands separators and saves the raw number', (tester) async {
    double? savedAmount;
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const ['Groceries'],
          onClose: () {},
          onSave: (amount, merchant, category) => savedAmount = amount,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '1234567.89');
    await tester.pump();

    expect(find.text('1,234,567.89'), findsOneWidget);

    await tester.tap(find.text('Save entry'));
    expect(savedAmount, 1234567.89);
  });

  testWidgets('Blocks save and shows a message when the amount exceeds the max', (tester) async {
    var saveCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const ['Groceries'],
          onClose: () {},
          onSave: (amount, merchant, category) => saveCalled = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '20000000000');
    await tester.tap(find.text('Save entry'));
    await tester.pump();

    expect(find.textContaining("can't be more than"), findsOneWidget);
    expect(saveCalled, isFalse);
  });

  testWidgets('Pre-fills the amount and merchant when given initial values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const ['Groceries'],
          initialAmount: 12.50,
          initialMerchant: 'Starbucks',
          onClose: () {},
          onSave: (amount, merchant, category) {},
        ),
      ),
    );

    expect(find.text('12.50'), findsOneWidget);
    expect(find.text('Starbucks'), findsOneWidget);
  });

  testWidgets('Still defaults to 0.00 and "Add a name" when no initial values are given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const ['Groceries'],
          onClose: () {},
          onSave: (amount, merchant, category) {},
        ),
      ),
    );

    expect(find.text('0.00'), findsOneWidget);
    expect(find.text('Add a name'), findsOneWidget);
  });
}
