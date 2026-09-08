import 'package:flutter/material.dart';
import '../models/category_spend.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_pressable.dart';
import '../widgets/stub_transaction_tile.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({
    super.key,
    required this.monthLabel,
    required this.categories,
    required this.recent,
    required this.activeNavIndex,
    required this.navItems,
    required this.onNavTap,
    required this.onScanTap,
    required this.onAddManualEntry,
    required this.onRefresh,
    this.onTransactionTap,
    this.onCategoryTap,
  });

  final String monthLabel;
  final List<CategorySpend> categories;
  final List<Transaction> recent;
  final int activeNavIndex;
  final List<StubNavItem> navItems;
  final ValueChanged<int> onNavTap;
  final VoidCallback onScanTap;
  final VoidCallback onAddManualEntry;
  final Future<void> Function() onRefresh;
  final ValueChanged<Transaction>? onTransactionTap;
  final ValueChanged<CategorySpend>? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final bg = isDark ? StubColors.bgDark : StubColors.bgLight;

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton(
        key: const Key('ledger-add-manual-entry'),
        onPressed: onAddManualEntry,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: StubColors.gradPop(Theme.of(context).brightness)),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Stub', style: StubText.domine(fontSize: 18, color: ink)),
                    Text(monthLabel.toUpperCase(), style: StubText.archivo(fontSize: 12, color: ink50, letterSpacing: 0.6)),
                  ],
                ),
                const SizedBox(height: 18),
                StubCard(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Column(children: [
                    for (final c in categories)
                      StubPressable(
                        onTap: onCategoryTap == null ? null : () => onCategoryTap!(c),
                        child: _CategoryRow(category: c),
                      ),
                  ]),
                ),
                const SizedBox(height: 22),
                Text('RECENT', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                const SizedBox(height: 8),
                for (final t in recent)
                  StubTransactionTile(transaction: t, onTap: onTransactionTap == null ? null : () => onTransactionTap!(t)),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: StubBottomNav(items: navItems, activeIndex: activeNavIndex, onTap: onNavTap, onScanTap: onScanTap),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});
  final CategorySpend category;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;
    final fraction = category.fraction;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: category.color)),
          const SizedBox(width: 10),
          Expanded(child: Text(category.name, style: StubText.archivo(fontSize: 14, color: ink))),
          Text(
            fraction == null ? 'No budget set' : '${(fraction * 100).round()}%',
            style: StubText.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: fraction == null ? ink50 : ink),
          ),
        ],
      ),
    );
  }
}
