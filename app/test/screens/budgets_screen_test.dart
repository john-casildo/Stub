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
          onRefresh: () async {},
        ),
      ),
    );
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('71%'), findsOneWidget);
    expect(find.text('+ Add a category'), findsOneWidget);
  });

  testWidgets('Shows an empty-state message when there are no categories', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BudgetsScreen(
          monthLabel: 'August',
          budgets: const [],
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
          onRefresh: () async {},
        ),
      ),
    );
    expect(find.textContaining('No categories yet'), findsOneWidget);
  });

  testWidgets('BudgetsScreen calls onDeleteCategory with the tapped row\'s categoryId', (tester) async {
    String? deletedId;
    await tester.pumpWidget(
      MaterialApp(
        home: BudgetsScreen(
          monthLabel: 'August',
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
          onRefresh: () async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('delete-category-c1')));
    expect(deletedId, 'c1');
  });

  testWidgets('Tapping a budget row calls onCategoryTap, and the delete button still works independently', (tester) async {
    BudgetLimit? tapped;
    String? deletedId;
    final budget = BudgetLimit(
      id: 'b1',
      categoryId: 'c1',
      name: 'Groceries',
      spent: 212,
      limit: 300,
      periodType: BudgetPeriodType.monthly,
      periodStart: DateTime(2026, 8, 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BudgetsScreen(
          monthLabel: 'August',
          budgets: [budget],
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
          onRefresh: () async {},
          onCategoryTap: (b) => tapped = b,
        ),
      ),
    );

    await tester.tap(find.text('Groceries'));
    expect(tapped, budget);
    expect(deletedId, isNull);

    await tester.tap(find.byKey(const Key('delete-category-c1')));
    expect(deletedId, 'c1');
  });

  testWidgets('Pulling down the budgets screen triggers onRefresh', (tester) async {
    var refreshed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: BudgetsScreen(
          monthLabel: 'August',
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
          onRefresh: () async => refreshed = true,
        ),
      ),
    );

    await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
  });
}
