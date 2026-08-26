import 'package:flutter/material.dart';
import '../models/budget_limit.dart';
import '../models/category_spend.dart';
import '../models/transaction.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_icon.dart';
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

const _sampleRecent = [
  Transaction(merchant: 'Corner Market', amount: 18.42, category: 'Groceries', source: TransactionSource.receipt, dateLabel: 'Today'),
  Transaction(merchant: 'Sarah K.', amount: 32.00, category: 'Dining out', source: TransactionSource.paymentApp, dateLabel: 'Yesterday'),
  Transaction(merchant: 'Chase Checking', amount: 14.99, category: 'Subscriptions', source: TransactionSource.bankScreenshot, dateLabel: 'Mon'),
];

const _sampleBudgets = [
  BudgetLimit(name: 'Groceries', spent: 212, limit: 300),
  BudgetLimit(name: 'Dining out', spent: 96, limit: 100),
  BudgetLimit(name: 'Subscriptions', spent: 42, limit: 60),
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

  // Not wired to a UI trigger yet — none of the composed screens (ledger,
  // budgets) expose a manual-entry entry point in the current mockup set.
  // Kept so the modal is ready to hook up once one does.
  // ignore: unused_element
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
    // Tab 2 (Profile) has no screen in the original mockup set — falls
    // back to Ledger until a Profile screen is designed.
    if (_tabIndex == 1) {
      return BudgetsScreen(
        monthLabel: 'August',
        totalBudgeted: 2400,
        totalSpent: 1488,
        budgets: _sampleBudgets,
        activeNavIndex: _tabIndex,
        navItems: _navItems,
        onNavTap: (i) => setState(() => _tabIndex = i),
        onScanTap: _openScan,
        onAddCategory: () {},
      );
    }
    return LedgerScreen(
      monthLabel: 'August',
      leftToSpend: 1842.30,
      leftToSpendFraction: 0.674,
      categories: _sampleCategories,
      recent: _sampleRecent,
      activeNavIndex: _tabIndex,
      navItems: _navItems,
      onNavTap: (i) => setState(() => _tabIndex = i),
      onScanTap: _openScan,
      onTransactionTap: _openEditEntry,
    );
  }
}
