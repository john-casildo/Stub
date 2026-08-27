import 'package:flutter/material.dart';
import '../models/budget_limit.dart';
import '../models/category_spend.dart';
import '../models/transaction.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_icon.dart';
import 'add_category_screen.dart';
import 'budgets_screen.dart';
import 'edit_entry_screen.dart';
import 'ledger_screen.dart';
import 'manual_entry_screen.dart';
import 'scan_screen.dart';

const _navItems = [
  StubNavItem(icon: StubIcons.home, label: 'Home'),
  StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
  StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
];

// Sample data matching mockups.html exactly — replace with real
// Supabase-backed queries once the schema exists (CLAUDE.md's Supabase
// section: not designed yet).
const _sampleCategories = [
  CategorySpend(name: 'Groceries', amount: 212.40, color: Color(0xFF0080FF)),
  CategorySpend(name: 'Dining out', amount: 96.10, color: Color(0xFF4B7A5B)),
  CategorySpend(name: 'Subscriptions', amount: 41.97, color: Color(0xFF8C6A2F)),
  CategorySpend(name: 'Transport', amount: 63.25, color: Color(0xFF5B6B8C)),
];

final _sampleRecent = [
  Transaction(id: 't1', categoryId: 'c1', merchant: 'Corner Market', amount: 18.42, category: 'Groceries', source: TransactionSource.receipt, occurredAt: DateTime.now()),
  Transaction(id: 't2', categoryId: 'c2', merchant: 'Sarah K.', amount: 32.00, category: 'Dining out', source: TransactionSource.paymentApp, occurredAt: DateTime.now().subtract(const Duration(days: 1))),
  Transaction(id: 't3', categoryId: 'c3', merchant: 'Chase Checking', amount: 14.99, category: 'Subscriptions', source: TransactionSource.bankScreenshot, occurredAt: DateTime.now().subtract(const Duration(days: 3))),
];

final _sampleBudgets = [
  BudgetLimit(id: 'b1', categoryId: 'c1', name: 'Groceries', spent: 212, limit: 300, periodType: BudgetPeriodType.monthly, periodStart: DateTime(2026, 8, 1)),
  BudgetLimit(id: 'b2', categoryId: 'c2', name: 'Dining out', spent: 96, limit: 100, periodType: BudgetPeriodType.monthly, periodStart: DateTime(2026, 8, 1)),
  BudgetLimit(id: 'b3', categoryId: 'c3', name: 'Subscriptions', spent: 42, limit: 60, periodType: BudgetPeriodType.monthly, periodStart: DateTime(2026, 8, 1)),
];

/// Owns bottom-nav tab state and pushes the modal screens (scan, edit
/// entry, manual entry). See the scope note in this task for what's
/// intentionally sample data / unimplemented here.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tabIndex = 0;

  void _openScan() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScanScreen(
        merchant: 'Corner Market',
        amount: 18.42,
        category: 'Groceries',
        onClose: () => Navigator.of(context).pop(),
        onAddToLedger: () => Navigator.of(context).pop(),
      ),
    ));
  }

  void _openEditEntry(Transaction transaction) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditEntryScreen(
        merchant: transaction.merchant,
        amount: transaction.amount,
        categories: const ['Groceries', 'Dining', 'Household'],
        selectedCategory: transaction.category,
        sourceLabel: transaction.dateLabel,
        onClose: () => Navigator.of(context).pop(),
        onSave: (_) => Navigator.of(context).pop(),
        onDelete: () => Navigator.of(context).pop(),
      ),
    ));
  }

  void _openAddCategory() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddCategoryScreen(
        onClose: () => Navigator.of(context).pop(),
        onSave: (name, limit, type, start, end) => Navigator.of(context).pop(),
      ),
    ));
  }

  void _openManualEntry() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ManualEntryScreen(
        categories: const ['Groceries', 'Dining', 'Transport'],
        onClose: () => Navigator.of(context).pop(),
        onSave: (amount, merchant, category) => Navigator.of(context).pop(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (_tabIndex == 1) {
      content = BudgetsScreen(
        monthLabel: 'August',
        totalBudgeted: 2400,
        totalSpent: 1488,
        budgets: _sampleBudgets,
        activeNavIndex: _tabIndex,
        navItems: _navItems,
        onNavTap: (i) => setState(() => _tabIndex = i),
        onScanTap: _openScan,
        onAddCategory: _openAddCategory,
      );
    } else {
      // Tab 2 (Profile) has no screen in the original mockup set — falls
      // back to Ledger content until a Profile screen is designed. The nav
      // bar highlight must agree with what's actually on screen, so it's
      // forced to Home (0) here rather than passed through as Profile (2).
      content = LedgerScreen(
        monthLabel: 'August',
        leftToSpend: 1842.30,
        leftToSpendFraction: 0.674,
        categories: _sampleCategories,
        recent: _sampleRecent,
        activeNavIndex: _tabIndex == 2 ? 0 : _tabIndex,
        navItems: _navItems,
        onNavTap: (i) => setState(() => _tabIndex = i),
        onScanTap: _openScan,
        onAddManualEntry: _openManualEntry,
        onTransactionTap: _openEditEntry,
      );
    }

    // Keyed by which screen is showing (not the raw tab index) so Home<->
    // Profile — which render identical Ledger content — never cross-fades
    // against itself.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(key: ValueKey(_tabIndex == 1 ? 'budgets' : 'ledger'), child: content),
    );
  }
}
