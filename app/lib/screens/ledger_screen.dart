import 'package:flutter/material.dart';
import '../models/category_spend.dart';
import '../models/transaction.dart';
import '../theme/budget_status.dart';
import '../theme/category_icons.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_hero_amount.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_pressable.dart';
import '../widgets/stub_progress_ring.dart';
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
    this.overallFraction,
  });

  final String monthLabel;
  final List<CategorySpend> categories;
  final List<Transaction> recent;
  /// Combined spent/limit across every budgeted category (0.0-1.2, same
  /// scale as `BudgetLimit.fraction`) — null when no category has a
  /// budget at all, in which case the hero is omitted.
  final double? overallFraction;
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
    final onAccent = isDark ? StubColors.onAccentDark : StubColors.onAccentLight;
    final overallStatus = budgetStatusForFraction(overallFraction);

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: StubPressable(
        key: const Key('ledger-add-manual-entry'),
        onTap: onAddManualEntry,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: StubColors.gradPop(Theme.of(context).brightness)),
          child: Center(child: Icon(Icons.add, size: 30, color: onAccent)),
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
                if (overallFraction != null) ...[
                  StubCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('OVERALL', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                              const SizedBox(height: 6),
                              StubHeroAmount.percent(
                                fraction: overallFraction!,
                                fontSize: 26,
                                flatColor: budgetStatusColor(overallStatus, isDark ? Brightness.dark : Brightness.light),
                              ),
                            ],
                          ),
                        ),
                        StubProgressRing(progress: overallFraction!, status: overallStatus),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (categories.isEmpty)
                  StubCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No categories yet — add one from the Budgets tab to start tracking.',
                          textAlign: TextAlign.center,
                          style: StubText.archivo(fontSize: 13, color: ink50),
                        ),
                      ),
                    ),
                  )
                else
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
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No transactions yet — scan a receipt or add one manually.',
                      style: StubText.archivo(fontSize: 13, color: ink50),
                    ),
                  )
                else
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
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final fraction = category.fraction;
    final statusColor = budgetStatusColor(budgetStatusForFraction(fraction), brightness);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          StubIcon(categoryIconData(category.icon), size: 18, color: category.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: StubText.archivo(fontSize: 14, color: statusColor ?? ink),
            ),
          ),
          Text(
            fraction == null ? 'No budget set' : '${(fraction * 100).round()}%',
            style: StubText.unbounded(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: fraction == null ? ink50 : (statusColor ?? ink),
            ),
          ),
        ],
      ),
    );
  }
}
