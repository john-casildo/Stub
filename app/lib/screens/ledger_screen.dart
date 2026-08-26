import 'package:flutter/material.dart';
import '../models/category_spend.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_progress_ring.dart';
import '../widgets/stub_transaction_tile.dart';

String _formatCurrency(double amount) {
  final fixed = amount.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '${buffer.toString()}.${parts[1]}';
}

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({
    super.key,
    required this.monthLabel,
    required this.leftToSpend,
    required this.leftToSpendFraction,
    required this.categories,
    required this.recent,
    required this.activeNavIndex,
    required this.navItems,
    required this.onNavTap,
    required this.onScanTap,
    this.onTransactionTap,
  });

  final String monthLabel;
  final double leftToSpend;
  final double leftToSpendFraction;
  final List<CategorySpend> categories;
  final List<Transaction> recent;
  final int activeNavIndex;
  final List<StubNavItem> navItems;
  final ValueChanged<int> onNavTap;
  final VoidCallback onScanTap;
  final ValueChanged<Transaction>? onTransactionTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final bg = isDark ? StubColors.bgDark : StubColors.bgLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('LEFT TO SPEND', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                                const SizedBox(height: 6),
                                Text('\$${_formatCurrency(leftToSpend)}', style: StubText.unbounded(fontSize: 26, color: ink)),
                              ],
                            ),
                          ),
                          StubProgressRing(progress: leftToSpendFraction),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StubCard(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      child: Column(children: [for (final c in categories) _CategoryRow(category: c)]),
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
            StubBottomNav(items: navItems, activeIndex: activeNavIndex, onTap: onNavTap, onScanTap: onScanTap),
          ],
        ),
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
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
      child: Row(
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: category.color)),
          const SizedBox(width: 10),
          Expanded(child: Text(category.name, style: StubText.archivo(fontSize: 14, color: ink))),
          Text('\$${_formatCurrency(category.amount)}', style: StubText.unbounded(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
        ],
      ),
    );
  }
}
