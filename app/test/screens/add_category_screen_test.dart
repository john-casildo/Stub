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
          onSave: (name, limit, type, start, end, currencyCode, icon, colorIndex) {
            savedName = name;
            savedLimit = limit;
            savedType = type;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Groceries');
    await tester.enterText(find.byType(TextField).last, '300');
    await tester.ensureVisible(find.text('Save category'));
    await tester.tap(find.text('Save category'));
    await tester.pump();

    expect(savedName, 'Groceries');
    expect(savedLimit, 300);
    expect(savedType, BudgetPeriodType.monthly); // default selection
  });

  testWidgets('Defaults to no currency override, and picking one is passed through to onSave', (tester) async {
    String? savedCurrencyCode;

    await tester.pumpWidget(
      MaterialApp(
        home: AddCategoryScreen(
          onClose: () {},
          onSave: (name, limit, type, start, end, currencyCode, icon, colorIndex) => savedCurrencyCode = currencyCode,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Groceries');
    await tester.ensureVisible(find.text('Save category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save category'));
    await tester.pump();
    expect(savedCurrencyCode, isNull);

    await tester.ensureVisible(find.text('Default'));
    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();
    expect(find.text('EUR').last, findsOneWidget); // broad currency list, not just USD/CRC
    await tester.tap(find.text('EUR').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save category'));
    await tester.pump();
    expect(savedCurrencyCode, 'EUR');
  });

  testWidgets('Custom period with no dates set blocks save and shows a message', (tester) async {
    var saveCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AddCategoryScreen(
          onClose: () {},
          onSave: (name, limit, type, start, end, currencyCode, icon, colorIndex) => saveCalled = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Groceries');
    await tester.ensureVisible(find.text('Custom'));
    await tester.tap(find.text('Custom'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save category'));
    await tester.ensureVisible(find.text('Save category'));
    await tester.tap(find.text('Save category'));
    await tester.pump();

    expect(find.text('Pick both a start and end date for a custom period.'), findsOneWidget);
    expect(saveCalled, isFalse);
  });

  testWidgets('Custom period with end date before start date blocks save and shows a message', (tester) async {
    var saveCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AddCategoryScreen(
          onClose: () {},
          onSave: (name, limit, type, start, end, currencyCode, icon, colorIndex) => saveCalled = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Groceries');
    await tester.ensureVisible(find.text('Custom'));
    await tester.tap(find.text('Custom'));
    await tester.pump();

    // Pick the start date via the real Material date picker: switch to
    // input mode and type a date later than the end date we'll pick next.
    await tester.ensureVisible(find.text('START DATE'));
    await tester.tap(find.text('START DATE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '08/20/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('END DATE'));
    await tester.tap(find.text('END DATE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '08/10/2026');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save category'));
    await tester.ensureVisible(find.text('Save category'));
    await tester.tap(find.text('Save category'));
    await tester.pump();

    expect(find.text('End date must be after the start date.'), findsOneWidget);
    expect(saveCalled, isFalse);
  });

  testWidgets('Defaults to the first icon/color, and picking others is passed through to onSave', (tester) async {
    String? savedIcon;
    int? savedColorIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: AddCategoryScreen(
          onClose: () {},
          onSave: (name, limit, type, start, end, currencyCode, icon, colorIndex) {
            savedIcon = icon;
            savedColorIndex = colorIndex;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Groceries');
    await tester.ensureVisible(find.text('Save category'));
    await tester.tap(find.text('Save category'));
    await tester.pump();
    expect(savedIcon, 'tag');
    expect(savedColorIndex, 0);

    // Second icon choice is 'cart', second color swatch is index 1.
    await tester.ensureVisible(find.byKey(const Key('category-icon-cart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-icon-cart')));
    await tester.ensureVisible(find.byKey(const Key('category-color-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category-color-1')));
    await tester.pump();
    await tester.ensureVisible(find.text('Save category'));
    await tester.tap(find.text('Save category'));
    await tester.pump();
    expect(savedIcon, 'cart');
    expect(savedColorIndex, 1);
  });

  testWidgets('Blocks typing a limit above the sanity cap at the keystroke level', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddCategoryScreen(
          onClose: () {},
          onSave: (name, limit, type, start, end, currencyCode, icon, colorIndex) {},
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).last, '20000000000');
    await tester.pump();

    expect(find.text('20000000000'), findsNothing);
    expect(find.text('20,000,000,000'), findsNothing);
  });

  testWidgets('Category name field enforces a max length', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddCategoryScreen(
          onClose: () {},
          onSave: (name, limit, type, start, end, currencyCode, icon, colorIndex) {},
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.maxLength, 40);
  });

  testWidgets('Limit field shows live thousands separators as you type, and saves the raw number', (tester) async {
    double? savedLimit;

    await tester.pumpWidget(
      MaterialApp(
        home: AddCategoryScreen(
          onClose: () {},
          onSave: (name, limit, type, start, end, currencyCode, icon, colorIndex) => savedLimit = limit,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Groceries');
    await tester.enterText(find.byType(TextField).last, '1234567.89');
    await tester.pump();

    expect(find.text('1,234,567.89'), findsOneWidget);

    await tester.ensureVisible(find.text('Save category'));
    await tester.tap(find.text('Save category'));
    await tester.pump();

    expect(savedLimit, 1234567.89);
  });
}
