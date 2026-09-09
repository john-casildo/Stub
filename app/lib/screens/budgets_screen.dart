import 'package:flutter/material.dart';
import '../models/budget_limit.dart';
import '../theme/budget_status.dart';
import '../theme/category_colors.dart';
import '../theme/category_icons.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_pressable.dart';
import '../widgets/stub_progress_bar.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({
    super.key,
    required this.monthLabel,
    required this.budgets,
    required this.activeNavIndex,
    required this.navItems,
    required this.onNavTap,
    required this.onScanTap,
    required this.onAddCategory,
    required this.onDeleteCategory,
    required this.onRefresh,
    this.onCategoryTap,
  });

  final String monthLabel;
  final List<BudgetLimit> budgets;
  final int activeNavIndex;
  final List<StubNavItem> navItems;
  final ValueChanged<int> onNavTap;
  final VoidCallback onScanTap;
  final VoidCallback onAddCategory;
  final ValueChanged<String> onDeleteCategory;
  final Future<void> Function() onRefresh;
  final ValueChanged<BudgetLimit>? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
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
                Text('CATEGORY LIMITS', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                const SizedBox(height: 10),
                if (budgets.isEmpty)
                  StubCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No categories yet — add one below to start budgeting.',
                          textAlign: TextAlign.center,
                          style: StubText.archivo(fontSize: 13, color: ink50),
                        ),
                      ),
                    ),
                  )
                else
                  StubCard(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Column(children: [
                      for (final b in budgets)
                        StubPressable(
                          onTap: onCategoryTap == null ? null : () => onCategoryTap!(b),
                          child: _BudgetRow(budget: b, onDelete: () => onDeleteCategory(b.categoryId)),
                        ),
                    ]),
                  ),
                const SizedBox(height: 14),
                StubPressable(
                  onTap: onAddCategory,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: ink.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('+ Add a category', style: StubText.archivo(fontSize: 13, fontWeight: FontWeight.w600, color: ink50)),
                    ),
                  ),
                ),
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

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.budget, required this.onDelete});
  final BudgetLimit budget;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;
    final color = categoryColor(categoryColorIndexFor(budget.categoryId, budget.colorIndex), brightness);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StubIcon(categoryIconData(budget.icon), size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  budget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StubText.archivo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: budgetStatusColor(budget.status, brightness) ?? ink,
                  ),
                ),
              ),
              Text(
                '${(budget.fraction * 100).round()}%',
                style: StubText.unbounded(fontSize: 13, color: budgetStatusColor(budget.status, brightness) ?? ink),
              ),
              IconButton(
                key: Key('delete-category-${budget.categoryId}'),
                icon: StubIcon(StubIcons.x, size: 14, color: ink.withValues(alpha: 0.4)),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          StubProgressBar.status(progress: budget.fraction, status: budget.status),
        ],
      ),
    );
  }
}
