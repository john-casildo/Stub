import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/category_spend.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/screens/ledger_screen.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';
import 'package:stub/widgets/stub_icon.dart';

void main() {
  testWidgets('LedgerScreen shows hero amount, categories, and recent transactions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LedgerScreen(
          monthLabel: 'August',
          leftToSpend: 1842.30,
          leftToSpendFraction: 0.674,
          categories: const [CategorySpend(name: 'Groceries', amount: 212.40, color: Colors.blue)],
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
        ),
      ),
    );
    expect(find.textContaining('1,842.30'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Corner Market'), findsOneWidget);
  });

  testWidgets('LedgerScreen shows a manual-entry FAB that calls onAddManualEntry', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: LedgerScreen(
      monthLabel: 'August',
      leftToSpend: 1842.30,
      leftToSpendFraction: 0.674,
      categories: const [CategorySpend(name: 'Groceries', amount: 212.40, color: Colors.blue)],
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
    )));

    await tester.tap(find.byKey(const Key('ledger-add-manual-entry')));
    expect(tapped, isTrue);
  });
}
