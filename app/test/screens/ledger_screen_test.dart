import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/category_spend.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/screens/ledger_screen.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';
import 'package:stub/widgets/stub_icon.dart';

void main() {
  testWidgets('LedgerScreen shows category percentages and recent transactions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerScreen(
          monthLabel: 'August',
          categories: const [CategorySpend(categoryId: 'c1', name: 'Groceries', fraction: 0.708, color: Colors.blue, icon: 'tag')],
          recent: [
            Transaction(id: 't1', categoryId: 'c1', merchant: 'Corner Market', amount: 18.42, category: 'Groceries', source: TransactionSource.receipt, occurredAt: DateTime.now()),
          ],
          activeNavIndex: 0,
          navItems: const [
            StubNavItem(icon: StubIcons.home, label: 'Home'),
            StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
            StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
          ],
          onNavTap: (_) {},
          onScanTap: () {},
          onAddManualEntry: () {},
          onRefresh: () async {},
        ),
      ),
    );
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('71%'), findsOneWidget);
    expect(find.text('Corner Market'), findsOneWidget);
  });

  testWidgets('A category with no budget shows "No budget set" instead of a percentage', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerScreen(
          monthLabel: 'August',
          categories: const [CategorySpend(categoryId: 'c1', name: 'Groceries', fraction: null, color: Colors.blue, icon: 'tag')],
          recent: const [],
          activeNavIndex: 0,
          navItems: const [
            StubNavItem(icon: StubIcons.home, label: 'Home'),
            StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
            StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
          ],
          onNavTap: (_) {},
          onScanTap: () {},
          onAddManualEntry: () {},
          onRefresh: () async {},
        ),
      ),
    );
    expect(find.text('No budget set'), findsOneWidget);
  });

  testWidgets('Pulling down the ledger triggers onRefresh', (tester) async {
    var refreshed = false;
    await tester.pumpWidget(MaterialApp(home: LedgerScreen(
      monthLabel: 'August',
      categories: const [CategorySpend(categoryId: 'c1', name: 'Groceries', fraction: 0.708, color: Colors.blue, icon: 'tag')],
      recent: [
        Transaction(id: 't1', categoryId: 'c1', merchant: 'Corner Market', amount: 18.42, category: 'Groceries', source: TransactionSource.receipt, occurredAt: DateTime.now()),
      ],
      activeNavIndex: 0,
      navItems: const [
        StubNavItem(icon: StubIcons.home, label: 'Home'),
        StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
        StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
      ],
      onNavTap: (_) {},
      onScanTap: () {},
      onAddManualEntry: () {},
      onRefresh: () async => refreshed = true,
    )));

    await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(refreshed, isTrue);
  });

  testWidgets('LedgerScreen shows a manual-entry FAB that calls onAddManualEntry', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: LedgerScreen(
      monthLabel: 'August',
      categories: const [CategorySpend(categoryId: 'c1', name: 'Groceries', fraction: 0.708, color: Colors.blue, icon: 'tag')],
      recent: [
        Transaction(id: 't1', categoryId: 'c1', merchant: 'Corner Market', amount: 18.42, category: 'Groceries', source: TransactionSource.receipt, occurredAt: DateTime.now()),
      ],
      activeNavIndex: 0,
      navItems: const [
        StubNavItem(icon: StubIcons.home, label: 'Home'),
        StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
        StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
      ],
      onNavTap: (_) {},
      onScanTap: () {},
      onAddManualEntry: () => tapped = true,
      onRefresh: () async {},
    )));

    await tester.tap(find.byKey(const Key('ledger-add-manual-entry')));
    expect(tapped, isTrue);
  });

  testWidgets('Tapping a category row calls onCategoryTap with its categoryId', (tester) async {
    String? tappedId;
    await tester.pumpWidget(MaterialApp(home: LedgerScreen(
      monthLabel: 'August',
      categories: const [CategorySpend(categoryId: 'c1', name: 'Groceries', fraction: 0.708, color: Colors.blue, icon: 'tag')],
      recent: const [],
      activeNavIndex: 0,
      navItems: const [
        StubNavItem(icon: StubIcons.home, label: 'Home'),
        StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
        StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
      ],
      onNavTap: (_) {},
      onScanTap: () {},
      onAddManualEntry: () {},
      onRefresh: () async {},
      onCategoryTap: (spend) => tappedId = spend.categoryId,
    )));

    await tester.tap(find.text('Groceries'));
    expect(tappedId, 'c1');
  });

  testWidgets('Omits the OVERALL hero when overallFraction is null', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LedgerScreen(
      monthLabel: 'August',
      categories: const [CategorySpend(categoryId: 'c1', name: 'Groceries', fraction: null, color: Colors.blue, icon: 'tag')],
      recent: const [],
      activeNavIndex: 0,
      navItems: const [
        StubNavItem(icon: StubIcons.home, label: 'Home'),
        StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
        StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
      ],
      onNavTap: (_) {},
      onScanTap: () {},
      onAddManualEntry: () {},
      onRefresh: () async {},
    )));

    expect(find.text('OVERALL'), findsNothing);
  });

  testWidgets('Shows the OVERALL hero with the combined percentage when set', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LedgerScreen(
      monthLabel: 'August',
      categories: const [CategorySpend(categoryId: 'c1', name: 'Groceries', fraction: 0.708, color: Colors.blue, icon: 'tag')],
      recent: const [],
      activeNavIndex: 0,
      navItems: const [
        StubNavItem(icon: StubIcons.home, label: 'Home'),
        StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
        StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
      ],
      onNavTap: (_) {},
      onScanTap: () {},
      onAddManualEntry: () {},
      onRefresh: () async {},
      overallFraction: 0.72,
    )));

    expect(find.text('OVERALL'), findsOneWidget);
    expect(find.text('72%'), findsOneWidget);
  });

  testWidgets('Shows empty-state messages when there are no categories or transactions', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LedgerScreen(
      monthLabel: 'August',
      categories: const [],
      recent: const [],
      activeNavIndex: 0,
      navItems: const [
        StubNavItem(icon: StubIcons.home, label: 'Home'),
        StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
        StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
      ],
      onNavTap: (_) {},
      onScanTap: () {},
      onAddManualEntry: () {},
      onRefresh: () async {},
    )));

    expect(find.textContaining('No categories yet'), findsOneWidget);
    expect(find.textContaining('No transactions yet'), findsOneWidget);
  });
}
