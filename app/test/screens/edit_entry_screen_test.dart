import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/category.dart';
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
          categories: const [
            Category(id: 'c1', name: 'Groceries'),
            Category(id: 'c2', name: 'Dining'),
            Category(id: 'c3', name: 'Household'),
          ],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan',
          dateLabel: 'Today',
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
    expect(find.text('Receipt scan'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.text('Dining'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    expect(savedMerchant, 'Corner Market');
    expect(savedAmount, 18.42);
    expect(savedCategory, 'Dining');
  });

  testWidgets('Amount symbol switches to the newly-selected category\'s own currency', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          merchant: 'Corner Market',
          amount: 18.42,
          categories: const [
            Category(id: 'c1', name: 'Groceries'),
            Category(id: 'c2', name: 'Costa Rica trip', currencyCode: 'CRC'),
          ],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan',
          dateLabel: 'Today',
          onClose: () {},
          onSave: (_, _, _) {},
          onDelete: () {},
        ),
      ),
    );

    expect(find.textContaining('\$18.42'), findsOneWidget);

    await tester.tap(find.text('Costa Rica trip'));
    await tester.pump();

    expect(find.textContaining('₡18.42'), findsOneWidget);
  });

  testWidgets('Tapping the merchant field opens an editable dialog that updates the value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          merchant: 'Corner Market',
          amount: 18.42,
          categories: const [Category(id: 'c1', name: 'Groceries')],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan',
          dateLabel: 'Today',
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
          categories: const [Category(id: 'c1', name: 'Groceries')],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan',
          dateLabel: 'Today',
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
          categories: const [Category(id: 'c1', name: 'Groceries')],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan',
          dateLabel: 'Today',
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
          categories: const [Category(id: 'c1', name: 'Groceries')],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan',
          dateLabel: 'Today',
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
