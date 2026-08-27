import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/budget_limit.dart';
import 'package:stub/screens/budgets_screen.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';
import 'package:stub/widgets/stub_icon.dart';

void main() {
  testWidgets('BudgetsScreen shows total and per-category rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BudgetsScreen(
          monthLabel: 'August',
          totalBudgeted: 2400,
          totalSpent: 1488,
          budgets: [
            BudgetLimit(
              id: 'b1',
              categoryId: 'c1',
              name: 'Groceries',
              spent: 212,
              limit: 300,
              periodType: BudgetPeriodType.monthly,
              periodStart: DateTime(2026, 8, 1),
            ),
          ],
          activeNavIndex: 1,
          navItems: const [
            StubNavItem(icon: StubIcons.home, label: 'Home'),
            StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
            StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
          ],
          onNavTap: (_) {},
          onScanTap: () {},
          onAddCategory: () {},
          onDeleteCategory: (_) {},
        ),
      ),
    );
    expect(find.textContaining('2,400.00'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('+ Add a category'), findsOneWidget);
  });

  testWidgets('BudgetsScreen calls onDeleteCategory with the tapped row\'s categoryId', (tester) async {
    String? deletedId;
    await tester.pumpWidget(
      MaterialApp(
        home: BudgetsScreen(
          monthLabel: 'August',
          totalBudgeted: 2400,
          totalSpent: 1488,
          budgets: [
            BudgetLimit(
              id: 'b1',
              categoryId: 'c1',
              name: 'Groceries',
              spent: 212,
              limit: 300,
              periodType: BudgetPeriodType.monthly,
              periodStart: DateTime(2026, 8, 1),
            ),
          ],
          activeNavIndex: 1,
          navItems: const [
            StubNavItem(icon: StubIcons.home, label: 'Home'),
            StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
            StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
          ],
          onNavTap: (_) {},
          onScanTap: () {},
          onAddCategory: () {},
          onDeleteCategory: (id) => deletedId = id,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('delete-category-c1')));
    expect(deletedId, 'c1');
  });
}
