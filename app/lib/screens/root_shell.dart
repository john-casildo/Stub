import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/account_link_service.dart';
import '../data/budget_repository.dart';
import '../data/category_repository.dart';
import '../data/local_prefs.dart';
import '../data/text_recognition_service.dart';
import '../data/transaction_repository.dart';
import '../models/budget_limit.dart';
import '../models/category.dart';
import '../models/category_spend.dart';
import '../models/transaction.dart';
import '../theme/category_colors.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/csv_export.dart';
import '../util/receipt_parser.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_loading_indicator.dart';
import 'add_category_screen.dart';
import 'budgets_screen.dart';
import 'category_detail_screen.dart';
import 'edit_entry_screen.dart';
import 'ledger_screen.dart';
import 'manual_entry_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

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
    required this.accountLinkService,
    required this.themeModeNotifier,
    required this.currencyNotifier,
    required this.localPrefs,
    required this.textRecognitionService,
    this.initialManualEntryAmount,
    this.initialManualEntryMerchant,
  });

  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;
  final AccountLinkService accountLinkService;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<String> currencyNotifier;
  final LocalPrefs localPrefs;
  final TextRecognitionService textRecognitionService;
  /// Set once, by `StubApp`, when the app was opened via a
  /// `com.stubapp.stub://log-expense` Siri Shortcuts deep link (see
  /// `util/deep_link.dart`). `StubApp` clears its own pending state
  /// immediately after passing these along, so they're only ever
  /// non-null on the one build where they should actually open
  /// `ManualEntryScreen`.
  final double? initialManualEntryAmount;
  final String? initialManualEntryMerchant;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tabIndex = 0;
  late Future<_ShellData> _dataFuture;
  // The last successfully-loaded data, kept around so a reload triggered
  // after a write (_guardedWrite always calls _reload()) can keep
  // rendering real content instead of tearing the whole screen down to a
  // spinner while refetching — that both flashes distractingly and, since
  // it unmounts LedgerScreen/StubProgressRing entirely, made the progress
  // ring restart its fill animation from zero on every single write.
  _ShellData? _lastData;
  // Guards against re-opening ManualEntryScreen if this widget rebuilds
  // for an unrelated reason (tab switch, reload) after already consuming
  // widget.initialManualEntryAmount/Merchant once.
  bool _consumedPendingManualEntry = false;

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

  /// The category's budget fraction (period-scoped progress toward its
  /// limit) — null when the category has no budget at all, so there's
  /// nothing to show a percentage of.
  double? _fractionFor(_ShellData data, String categoryId) {
    for (final budget in data.budgets) {
      if (budget.categoryId == categoryId) return budget.fraction;
    }
    return null;
  }

  String? _currencyCodeFor(_ShellData data, String categoryId) {
    for (final category in data.categories) {
      if (category.id == categoryId) return category.currencyCode;
    }
    return null;
  }

  /// Pull-to-refresh needs a `Future` it can await to know when to hide
  /// the spinner — `_reload` itself is fire-and-forget (`setState` just
  /// swaps in a new future), so this kicks off the same reload and then
  /// waits on it.
  Future<void> _handleRefresh() {
    _reload();
    return _dataFuture;
  }

  void _openScan(List<Transaction> transactions) {
    final knownMerchants = {for (final t in transactions) t.merchant}.toList();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScanScreen(
        textRecognitionService: widget.textRecognitionService,
        onClose: () => Navigator.of(context).pop(),
        onScanned: (parsed, source) => _handleScanned(parsed, source),
        knownMerchants: knownMerchants,
      ),
    ));
  }

  /// `ScanScreen` can fire `onScanned` after it's already popped itself
  /// (e.g. the user tapped the X close button while OCR was still running
  /// — `_continue`'s `await` has no guard against that). Without the
  /// `canPop()` check here, a mistimed cancel would make this method pop
  /// twice: once for the already-gone `ScanScreen` route, and a second
  /// time popping `RootShell` itself (the `home` route, which
  /// `Navigator.pop()` has no last-route protection against), leaving a
  /// broken/empty stack that `EditEntryScreen` then gets pushed onto.
  void _handleScanned(ParsedReceipt parsed, TransactionSource source) {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // close ScanScreen
    }
    _dataFuture.then((data) {
      if (mounted) _openScanCreateFlow(parsed, source, data.categories);
    });
  }

  void _openScanCreateFlow(ParsedReceipt parsed, TransactionSource source, List<Category> categories) {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a category first, then log an expense.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditEntryScreen(
        isCreating: true,
        merchant: parsed.merchant ?? '',
        amount: parsed.amount ?? 0,
        categories: [for (final c in categories) c.name],
        selectedCategory: categories.first.name,
        sourceLabel: switch (source) {
          TransactionSource.receipt => 'Receipt scan',
          TransactionSource.paymentApp => 'Payment app scan',
          TransactionSource.bankScreenshot => 'Bank screenshot scan',
          TransactionSource.manual => 'Manual',
        },
        onClose: () => Navigator.of(context).pop(),
        onSave: (merchant, amount, categoryName) => _guardedWrite(() async {
          final category = categories.firstWhere((c) => c.name == categoryName);
          await widget.transactionRepository.create(Transaction(
            id: '',
            categoryId: category.id,
            merchant: merchant,
            amount: amount,
            category: categoryName,
            source: source,
            occurredAt: parsed.occurredAt ?? DateTime.now(),
          ));
        }, onSuccess: () => Navigator.of(context).pop()),
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
        onSave: (merchant, amount, category) => _guardedWrite(() async {
          final selectedCategory = categories.firstWhere((c) => c.name == category);
          await widget.transactionRepository.update(
            transaction.copyWith(
              merchant: merchant,
              amount: amount,
              category: category,
              categoryId: selectedCategory.id,
            ),
          );
        }, onSuccess: () => Navigator.of(context).pop()),
        onDelete: () => _guardedWrite(
          () => widget.transactionRepository.delete(transaction.id),
          onSuccess: () => Navigator.of(context).pop(),
        ),
      ),
    ));
  }

  /// Opened by tapping a category row on `LedgerScreen` or a budget row
  /// on `BudgetsScreen` — every transaction saved under [categoryId],
  /// reusing `_openEditEntry` for the tap-through so correcting an entry
  /// works the same way it does everywhere else.
  void _openCategoryDetail(String categoryId, String categoryName, _ShellData data) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CategoryDetailScreen(
        categoryName: categoryName,
        transactions: data.transactions.where((t) => t.categoryId == categoryId).toList(),
        onClose: () => Navigator.of(context).pop(),
        onTransactionTap: (t) => _openEditEntry(t, data.categories),
        fraction: _fractionFor(data, categoryId),
        currencyCode: _currencyCodeFor(data, categoryId),
      ),
    ));
  }

  void _openSettings(_ShellData data) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        localPrefs: widget.localPrefs,
        themeModeNotifier: widget.themeModeNotifier,
        currencyNotifier: widget.currencyNotifier,
        onClose: () => Navigator.of(context).pop(),
        onExportData: _exportData,
        onDeleteAllData: () => _deleteAllData(data),
      ),
    ));
  }

  /// `SupabaseTransactionRepository.list()` is capped by PostgREST's
  /// `max_rows` (1000) — a single call would silently omit any rows beyond
  /// the first page for a user with more transactions than that. Page
  /// through with `offset` until an empty page comes back, which is correct
  /// regardless of row count. Shared by `_exportData` (collects) and
  /// `_deleteAllData` (deletes as it goes, so its own loop re-lists from
  /// offset 0 each time instead of using this helper — see that method).
  Future<List<Transaction>> _fetchAllTransactions() async {
    final all = <Transaction>[];
    var batch = await widget.transactionRepository.list(offset: all.length);
    while (batch.isNotEmpty) {
      all.addAll(batch);
      batch = await widget.transactionRepository.list(offset: all.length);
    }
    return all;
  }

  /// `exportTransactionsCsv` does real I/O (temp file write + OS share
  /// sheet) and can fail — unlike every other write in this file, it's
  /// not a Postgrest call, so it doesn't go through `_guardedWrite`; a
  /// plain try/catch + snackbar is the right shape here.
  Future<void> _exportData() async {
    try {
      final transactions = await _fetchAllTransactions();
      await exportTransactionsCsv(transactions);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export data. Please try again.')),
        );
      }
    }
  }

  /// See `_fetchAllTransactions` for why this can't just read
  /// `data.transactions` — instead it re-lists (from offset 0, since each
  /// delete shrinks what offset 0 returns) and deletes repeatedly until
  /// `list()` comes back empty. Categories have no such cap concern in
  /// practice, so a single pass over the loaded snapshot is fine for those.
  ///
  /// Blocks the UI with a non-dismissible dialog for the duration so the
  /// user can't tap Settings' close button (or anything else) mid-delete,
  /// which could otherwise pop the wrong route once the operation
  /// finishes.
  ///
  /// Both error branches reload before showing their snackbar: the delete
  /// loop may have already removed hundreds of rows before failing, so
  /// leaving the stale pre-delete snapshot on screen would show phantom
  /// data until some unrelated write happened to trigger a reload.
  Future<void> _deleteAllData(_ShellData data) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: StubLoadingIndicator()),
    );
    try {
      var batch = await widget.transactionRepository.list();
      while (batch.isNotEmpty) {
        for (final t in batch) {
          await widget.transactionRepository.delete(t.id);
        }
        batch = await widget.transactionRepository.list();
      }
      for (final c in data.categories) {
        await widget.categoryRepository.delete(c.id);
      }
      if (mounted) Navigator.of(context).pop(); // dismiss the loading dialog
      if (mounted) Navigator.of(context).pop(); // pop Settings back to Profile
      if (mounted) _reload();
    } on PostgrestException catch (e) {
      if (mounted) Navigator.of(context).pop(); // dismiss the loading dialog
      if (mounted) _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessage(e))));
      }
    } catch (_) {
      if (mounted) Navigator.of(context).pop(); // dismiss the loading dialog
      if (mounted) _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  void _openAddCategory() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddCategoryScreen(
        onClose: () => Navigator.of(context).pop(),
        onSave: (name, limitAmount, periodType, periodStart, periodEnd, currencyCode) => _guardedWrite(() async {
          final category = await widget.categoryRepository.create(name, currencyCode: currencyCode);
          try {
            await widget.budgetRepository.create(
              categoryId: category.id,
              limitAmount: limitAmount,
              periodType: periodType,
              periodStart: periodStart,
              periodEnd: periodEnd,
            );
          } catch (e) {
            await widget.categoryRepository.delete(category.id);
            rethrow;
          }
        }, onSuccess: () => Navigator.of(context).pop()),
      ),
    ));
  }

  Future<void> _guardedWrite(Future<void> Function() write, {VoidCallback? onSuccess}) async {
    try {
      await write();
      if (mounted) onSuccess?.call();
      if (mounted) _reload();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessage(e))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  String _friendlyMessage(PostgrestException e) => switch (e.code) {
        '23503' => "Can't delete a category with existing transactions.",
        '23505' => 'A category with that name already exists.',
        '23514' => 'Please check the values you entered.',
        _ => 'Something went wrong. Please try again.',
      };

  void _openManualEntry(List<Category> categories, {double? initialAmount, String? initialMerchant}) {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a category first, then log an expense.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ManualEntryScreen(
        categories: [for (final c in categories) c.name],
        initialAmount: initialAmount,
        initialMerchant: initialMerchant,
        onClose: () => Navigator.of(context).pop(),
        onSave: (amount, merchant, categoryName) => _guardedWrite(() async {
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
        }, onSuccess: () => Navigator.of(context).pop()),
      ),
    ));
  }

  Future<void> _deleteCategory(String categoryId) async {
    try {
      await widget.categoryRepository.delete(categoryId);
      if (mounted) _reload();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendlyMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ShellData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? StubColors.bgDark : StubColors.bgLight;
        final ink = isDark ? StubColors.inkDark : StubColors.inkLight;

        if (snapshot.hasData) _lastData = snapshot.data;
        final data = snapshot.data ?? _lastData;

        if (data == null) {
          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: bg,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Something went wrong loading your data.', style: StubText.archivo(fontSize: 14, color: ink)),
                    const SizedBox(height: 16),
                    StubButton(label: 'Retry', onPressed: _reload),
                  ],
                ),
              ),
            );
          }
          return Scaffold(
            backgroundColor: bg,
            body: const Center(child: StubLoadingIndicator()),
          );
        }
        // A reload that fails while we already have `_lastData` (e.g. a
        // transient network blip on a background refresh) just keeps
        // showing that last-known-good data rather than replacing the
        // whole screen with a hard error — only the true first load (no
        // data at all yet) surfaces the retry screen above.

        if (!_consumedPendingManualEntry &&
            (widget.initialManualEntryAmount != null || widget.initialManualEntryMerchant != null)) {
          _consumedPendingManualEntry = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openManualEntry(
                data.categories,
                initialAmount: widget.initialManualEntryAmount,
                initialMerchant: widget.initialManualEntryMerchant,
              );
            }
          });
        }

        final Widget content;

        if (_tabIndex == 1) {
          content = BudgetsScreen(
            monthLabel: _monthLabel(),
            budgets: data.budgets,
            activeNavIndex: _tabIndex,
            navItems: _navItems,
            onNavTap: (i) => setState(() => _tabIndex = i),
            onScanTap: () => _openScan(data.transactions),
            onAddCategory: _openAddCategory,
            onDeleteCategory: _deleteCategory,
            onRefresh: _handleRefresh,
            onCategoryTap: (b) => _openCategoryDetail(b.categoryId, b.name, data),
          );
        } else if (_tabIndex == 2) {
          final totalEverTracked = data.transactions.fold<double>(0, (sum, t) => sum + t.amount);
          content = ProfileScreen(
            accountLinkService: widget.accountLinkService,
            totalEverTracked: totalEverTracked,
            categoryCount: data.categories.length,
            activeNavIndex: _tabIndex,
            navItems: _navItems,
            onNavTap: (i) => setState(() => _tabIndex = i),
            onScanTap: () => _openScan(data.transactions),
            onOpenSettings: () => _openSettings(data),
          );
        } else {
          // CategorySpend (and its per-category color) needs
          // Theme.of(context).brightness, which only exists here inside
          // build() — not inside the async _load() above, which runs
          // before any widget tree exists.
          final brightness = Theme.of(context).brightness;
          final categorySpends = <CategorySpend>[
            for (var i = 0; i < data.categories.length; i++)
              CategorySpend(
                categoryId: data.categories[i].id,
                name: data.categories[i].name,
                fraction: _fractionFor(data, data.categories[i].id),
                color: categoryColor(i, brightness),
              ),
          ];

          content = LedgerScreen(
            monthLabel: _monthLabel(),
            categories: categorySpends,
            recent: data.transactions,
            activeNavIndex: _tabIndex,
            navItems: _navItems,
            onNavTap: (i) => setState(() => _tabIndex = i),
            onScanTap: () => _openScan(data.transactions),
            onAddManualEntry: () => _openManualEntry(data.categories),
            onTransactionTap: (t) => _openEditEntry(t, data.categories),
            onRefresh: _handleRefresh,
            onCategoryTap: (c) => _openCategoryDetail(c.categoryId, c.name, data),
          );
        }

        // Keyed by which screen is showing so each tab cross-fades in cleanly.
        final screenKey = switch (_tabIndex) {
          1 => 'budgets',
          2 => 'profile',
          _ => 'ledger',
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(key: ValueKey(screenKey), child: content),
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
