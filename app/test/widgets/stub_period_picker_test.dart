import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/budget_limit.dart';
import 'package:stub/widgets/stub_period_picker.dart';

void main() {
  testWidgets('StubPeriodPicker reports type changes and shows custom date fields only when selected', (tester) async {
    BudgetPeriodType? changedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: StubPeriodPicker(
            selected: BudgetPeriodType.monthly,
            customStart: null,
            customEnd: null,
            onTypeChanged: (t) => changedTo = t,
            onCustomStartChanged: (_) {},
            onCustomEndChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('START DATE'), findsNothing);

    await tester.tap(find.text('Custom'));
    expect(changedTo, BudgetPeriodType.custom);
  });

  testWidgets('StubPeriodPicker shows start/end date fields when Custom is selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: StubPeriodPicker(
            selected: BudgetPeriodType.custom,
            customStart: DateTime(2026, 8, 1),
            customEnd: DateTime(2026, 8, 25),
            onTypeChanged: (_) {},
            onCustomStartChanged: (_) {},
            onCustomEndChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('START DATE'), findsOneWidget);
    expect(find.text('END DATE'), findsOneWidget);
  });
}
