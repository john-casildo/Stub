import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/edit_entry_screen.dart';

void main() {
  testWidgets('EditEntryScreen lets you switch category and save', (tester) async {
    String? savedMerchant;
    double? savedAmount;
    String? savedCategory;
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          merchant: 'Corner Market',
          amount: 18.42,
          categories: const ['Groceries', 'Dining', 'Household'],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan · Today',
          onClose: () {},
          onSave: (merchant, amount, category) {
            savedMerchant = merchant;
            savedAmount = amount;
            savedCategory = category;
          },
          onDelete: () {},
        ),
      ),
    );
    expect(find.text('Corner Market'), findsOneWidget);

    await tester.tap(find.text('Dining'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    expect(savedMerchant, 'Corner Market');
    expect(savedAmount, 18.42);
    expect(savedCategory, 'Dining');
  });

  testWidgets('Tapping the merchant field opens an editable dialog that updates the value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          merchant: 'Corner Market',
          amount: 18.42,
          categories: const ['Groceries'],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan · Today',
          onClose: () {},
          onSave: (_, _, _) {},
          onDelete: () {},
        ),
      ),
    );

    await tester.tap(find.text('Corner Market'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'New Merchant');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('New Merchant'), findsOneWidget);
  });

  testWidgets('isCreating hides the Delete button and onSave still fires once valid', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          isCreating: true,
          merchant: 'Corner Market',
          amount: 18.42,
          categories: const ['Groceries'],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan · Today',
          onClose: () {},
          onSave: (_, _, _) => saved = true,
          onDelete: () {},
        ),
      ),
    );

    expect(find.text('Delete entry'), findsNothing);
    await tester.tap(find.text('Save changes'));
    expect(saved, isTrue);
  });

  testWidgets('blocks save and shows a snackbar when merchant is empty', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          isCreating: true,
          merchant: '',
          amount: 18.42,
          categories: const ['Groceries'],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan · Today',
          onClose: () {},
          onSave: (_, _, _) => saved = true,
          onDelete: () {},
        ),
      ),
    );

    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(saved, isFalse);
    expect(find.text('Enter a merchant name before saving.'), findsOneWidget);
  });

  testWidgets('blocks save and shows a snackbar when amount is zero', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          isCreating: true,
          merchant: 'Corner Market',
          amount: 0,
          categories: const ['Groceries'],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan · Today',
          onClose: () {},
          onSave: (_, _, _) => saved = true,
          onDelete: () {},
        ),
      ),
    );

    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(saved, isFalse);
    expect(find.text('Enter an amount greater than \$0 before saving.'), findsOneWidget);
  });
}
