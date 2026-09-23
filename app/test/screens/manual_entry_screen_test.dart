import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/category.dart';
import 'package:stub/screens/manual_entry_screen.dart';

void main() {
  testWidgets('ManualEntryScreen saves the entered amount and category', (tester) async {
    double? savedAmount;
    String? savedCategory;
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const [
            Category(id: 'c1', name: 'Groceries'),
            Category(id: 'c2', name: 'Dining'),
            Category(id: 'c3', name: 'Transport'),
          ],
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
          categories: const [Category(id: 'c1', name: 'Groceries')],
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

  testWidgets('Pre-fills the amount and merchant when given initial values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const [Category(id: 'c1', name: 'Groceries')],
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

  testWidgets('Amount prefix switches to the selected category\'s own currency symbol', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const [
            Category(id: 'c1', name: 'Groceries'),
            Category(id: 'c2', name: 'Costa Rica trip', currencyCode: 'CRC'),
          ],
          onClose: () {},
          onSave: (amount, merchant, category) {},
        ),
      ),
    );

    expect(find.text('\$'), findsOneWidget);

    await tester.tap(find.text('Costa Rica trip'));
    await tester.pump();

    expect(find.text('₡'), findsOneWidget);
    expect(find.text('\$'), findsNothing);
  });

  testWidgets('Tapping the amount field selects the existing text so typing replaces it outright', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const [Category(id: 'c1', name: 'Groceries')],
          onClose: () {},
          onSave: (amount, merchant, category) {},
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    final selection = field.controller!.selection;
    expect(selection.baseOffset, 0);
    expect(selection.extentOffset, field.controller!.text.length);
  });

  testWidgets('Blocks typing an amount above the sanity cap at the keystroke level', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const [Category(id: 'c1', name: 'Groceries')],
          onClose: () {},
          onSave: (amount, merchant, category) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '20000000000');
    await tester.pump();

    expect(find.text('0.00'), findsOneWidget);
  });

  testWidgets('Still defaults to 0.00 and "Add a name" when no initial values are given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManualEntryScreen(
          categories: const [Category(id: 'c1', name: 'Groceries')],
          onClose: () {},
          onSave: (amount, merchant, category) {},
        ),
      ),
    );

    expect(find.text('0.00'), findsOneWidget);
    expect(find.text('Add a name'), findsOneWidget);
  });
}
