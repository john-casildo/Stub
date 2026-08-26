import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/edit_entry_screen.dart';

void main() {
  testWidgets('EditEntryScreen lets you switch category and save', (tester) async {
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: EditEntryScreen(
          merchant: 'Corner Market',
          amount: 18.42,
          categories: const ['Groceries', 'Dining', 'Household'],
          selectedCategory: 'Groceries',
          sourceLabel: 'Receipt scan · Today',
          onClose: () {},
          onSave: (category) => saved = category,
          onDelete: () {},
        ),
      ),
    );
    expect(find.text('Corner Market'), findsOneWidget);

    await tester.tap(find.text('Dining'));
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    expect(saved, 'Dining');
  });
}
