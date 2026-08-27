import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/budget_limit.dart';
import 'package:stub/screens/add_category_screen.dart';

void main() {
  testWidgets('AddCategoryScreen collects a name, limit, and monthly period, then saves', (tester) async {
    String? savedName;
    double? savedLimit;
    BudgetPeriodType? savedType;

    await tester.pumpWidget(
      MaterialApp(
        home: AddCategoryScreen(
          onClose: () {},
          onSave: (name, limit, type, start, end) {
            savedName = name;
            savedLimit = limit;
            savedType = type;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Groceries');
    await tester.enterText(find.byType(TextField).last, '300');
    await tester.tap(find.text('Save category'));
    await tester.pump();

    expect(savedName, 'Groceries');
    expect(savedLimit, 300);
    expect(savedType, BudgetPeriodType.monthly); // default selection
  });
}
