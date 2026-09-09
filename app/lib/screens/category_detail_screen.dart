import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme/budget_status.dart';
import '../theme/category_icons.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/currency.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_hero_amount.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_progress_ring.dart';
import '../widgets/stub_transaction_tile.dart';

/// Every transaction/receipt saved under one category — reachable by
/// tapping a category row on `LedgerScreen` or a budget row on
/// `BudgetsScreen`. `RootShell` owns navigation and pre-filters
/// [transactions] to this category, like every other screen here.
///
/// Shows the hero amount + ring combo that used to live as a single
/// combined total on `LedgerScreen`'s home screen — moved here (one per
/// category, in that category's own currency) since a single blended
/// total across categories in different currencies isn't meaningful.
/// [fraction] (progress toward [currencyCode]'s budget limit) is null
/// when the category has no budget, in which case there's no ring.
class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({
    super.key,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.transactions,
    required this.onClose,
    this.onTransactionTap,
    this.fraction,
    this.currencyCode,
    this.limit,
  });

  final String categoryName;
  /// Key into lib/theme/category_icons.dart's curated icon set.
  final String icon;
  final Color color;
  final List<Transaction> transactions;
  final VoidCallback onClose;
  final ValueChanged<Transaction>? onTransactionTap;
  final double? fraction;
  final String? currencyCode;
  /// The category's established budget limit, if it has one — shown
  /// alongside the total so the actual number you set is visible here,
  /// not just its progress ring/percentage.
  final double? limit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final total = transactions.fold<double>(0, (sum, t) => sum + t.amount);

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: onClose),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StubIcon(categoryIconData(icon), size: 18, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                categoryName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: StubText.archivo(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            StubCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                        const SizedBox(height: 6),
                        StubHeroAmount(amount: total, currencyCode: currencyCode, fontSize: 26),
                        if (limit != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'of ${formatCurrency(limit!, currencyCode: currencyCode)} limit',
                            style: StubText.archivo(fontSize: 12, color: ink50),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (fraction != null)
                    StubProgressRing(progress: fraction!, status: budgetStatusForFraction(fraction)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text(
                    'No transactions in $categoryName yet.',
                    style: StubText.archivo(fontSize: 14, color: ink50),
                  ),
                ),
              )
            else
              for (final t in transactions)
                StubTransactionTile(transaction: t, onTap: onTransactionTap == null ? null : () => onTransactionTap!(t)),
          ],
        ),
      ),
    );
  }
}
