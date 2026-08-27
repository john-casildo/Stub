import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/budget_repository.dart';
import '../data/category_repository.dart';
import '../data/transaction_repository.dart';
import '../models/budget_limit.dart';
import '../models/category.dart';
import '../models/category_spend.dart';
import '../models/transaction.dart';
import '../theme/category_colors.dart';
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

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _monthLabel() => _months[DateTime.now().month - 1];

/// Owns bottom-nav tab state, loads real data from its repositories, and
/// pushes the modal screens (scan, edit entry, manual entry, add
/// category). Data is loaded once on init and reloaded after any write
/// (`_reload`); see `_ShellData` for the shape carried between loads.
class RootShell extends StatefulWidget {
  const RootShell({
    super.key,
    required this.categoryRepository,
    required this.transactionRepository,
    required this.budgetRepository,
  });

  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tabIndex = 0;
  late Future<_ShellData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_ShellData> _load() async {
    final categories = await widget.categoryRepository.list();
    final transactions = await widget.transactionRepository.list();
    final budgets = await widget.budgetRepository.list();
    return _ShellData(categories: categories, transactions: transactions, budgets: budgets);
  }

  void _reload() => setState(() {
        _dataFuture = _load();
      });

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

  void _openEditEntry(Transaction transaction, List<Category> categories) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditEntryScreen(
        merchant: transaction.merchant,
        amount: transaction.amount,
        categories: [for (final c in categories) c.name],
        selectedCategory: transaction.category,
        sourceLabel: transaction.dateLabel,
        onClose: () => Navigator.of(context).pop(),
        onSave: (selectedCategory) async {
          final category = categories.firstWhere((c) => c.name == selectedCategory);
          await widget.transactionRepository.update(
            transaction.copyWith(category: selectedCategory, categoryId: category.id),
          );
          if (mounted) Navigator.of(context).pop();
          _reload();
        },
        onDelete: () async {
          await widget.transactionRepository.delete(transaction.id);
          if (mounted) Navigator.of(context).pop();
          _reload();
        },
      ),
    ));
  }

  void _openAddCategory() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddCategoryScreen(
        onClose: () => Navigator.of(context).pop(),
        onSave: (name, limitAmount, periodType, periodStart, periodEnd) async {
          final category = await widget.categoryRepository.create(name);
          await widget.budgetRepository.create(
            categoryId: category.id,
            limitAmount: limitAmount,
            periodType: periodType,
            periodStart: periodStart,
            periodEnd: periodEnd,
          );
          if (mounted) Navigator.of(context).pop();
          _reload();
        },
      ),
    ));
  }

  void _openManualEntry(List<Category> categories) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ManualEntryScreen(
        categories: [for (final c in categories) c.name],
        onClose: () => Navigator.of(context).pop(),
        onSave: (amount, merchant, categoryName) async {
          final category = categories.firstWhere((c) => c.name == categoryName);
          await widget.transactionRepository.create(Transaction(
            id: '',
            categoryId: category.id,
            merchant: merchant,
            amount: amount,
            category: categoryName,
            source: TransactionSource.manual,
            occurredAt: DateTime.now(),
          ));
          if (mounted) Navigator.of(context).pop();
          _reload();
        },
      ),
    ));
  }

  Future<void> _deleteCategory(String categoryId) async {
    try {
      await widget.categoryRepository.delete(categoryId);
      _reload();
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        // The ON DELETE RESTRICT rule firing — the category still has
        // transactions pointing at it.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Can't delete a category with existing transactions.")),
          );
        }
      } else {
        rethrow;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ShellData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Something went wrong loading your data.'),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        final Widget content;

        if (_tabIndex == 1) {
          final totalBudgeted = data.budgets.fold<double>(0, (sum, b) => sum + b.limit);
          final totalSpent = data.budgets.fold<double>(0, (sum, b) => sum + b.spent);
          content = BudgetsScreen(
            monthLabel: _monthLabel(),
            totalBudgeted: totalBudgeted,
            totalSpent: totalSpent,
            budgets: data.budgets,
            activeNavIndex: _tabIndex,
            navItems: _navItems,
            onNavTap: (i) => setState(() => _tabIndex = i),
            onScanTap: _openScan,
            onAddCategory: _openAddCategory,
            onDeleteCategory: _deleteCategory,
          );
        } else {
          // Tab 2 (Profile) has no screen in the original mockup set —
          // falls back to Ledger content until a Profile screen is
          // designed. The nav bar highlight must agree with what's
          // actually on screen, so it's forced to Home (0) here rather
          // than passed through as Profile (2).
          final totalLimit = data.budgets.fold<double>(0, (sum, b) => sum + b.limit);
          final totalSpent = data.budgets.fold<double>(0, (sum, b) => sum + b.spent);
          final leftToSpend = totalLimit - totalSpent;
          final leftToSpendFraction = totalLimit == 0 ? 0.0 : (1 - totalSpent / totalLimit).clamp(0.0, 1.0);

          // CategorySpend (and its per-category color) needs
          // Theme.of(context).brightness, which only exists here inside
          // build() — not inside the async _load() above, which runs
          // before any widget tree exists.
          final brightness = Theme.of(context).brightness;
          final categorySpends = <CategorySpend>[
            for (var i = 0; i < data.categories.length; i++)
              CategorySpend(
                name: data.categories[i].name,
                amount: data.transactions
                    .where((t) => t.categoryId == data.categories[i].id)
                    .fold<double>(0, (sum, t) => sum + t.amount),
                color: categoryColor(i, brightness),
              ),
          ];

          content = LedgerScreen(
            monthLabel: _monthLabel(),
            leftToSpend: leftToSpend,
            leftToSpendFraction: leftToSpendFraction,
            categories: categorySpends,
            recent: data.transactions,
            activeNavIndex: _tabIndex == 2 ? 0 : _tabIndex,
            navItems: _navItems,
            onNavTap: (i) => setState(() => _tabIndex = i),
            onScanTap: _openScan,
            onAddManualEntry: () => _openManualEntry(data.categories),
            onTransactionTap: (t) => _openEditEntry(t, data.categories),
          );
        }

        // Keyed by which screen is showing (not the raw tab index) so
        // Home<->Profile — which render identical Ledger content — never
        // cross-fades against itself.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(key: ValueKey(_tabIndex == 1 ? 'budgets' : 'ledger'), child: content),
        );
      },
    );
  }
}

class _ShellData {
  const _ShellData({required this.categories, required this.transactions, required this.budgets});
  final List<Category> categories;
  final List<Transaction> transactions;
  final List<BudgetLimit> budgets;
}
