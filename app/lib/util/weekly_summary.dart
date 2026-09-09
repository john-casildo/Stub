import '../models/transaction.dart';
import 'currency.dart';

/// The computed content of a weekly summary — total spent, and whichever
/// single category had the most spending that week (null if there were
/// no transactions at all).
class WeeklySummary {
  const WeeklySummary({required this.total, this.topCategory, this.topCategoryAmount});
  final double total;
  final String? topCategory;
  final double? topCategoryAmount;
}

/// [transactionsInWeek] should already be filtered to the target week —
/// this just aggregates. Null when the list is empty (nothing to
/// summarize, so the caller should skip notifying that week).
WeeklySummary? computeWeeklySummary(List<Transaction> transactionsInWeek) {
  if (transactionsInWeek.isEmpty) return null;
  final total = transactionsInWeek.fold<double>(0, (sum, t) => sum + t.amount);
  final byCategory = <String, double>{};
  for (final t in transactionsInWeek) {
    byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
  }
  final top = byCategory.entries.reduce((a, b) => b.value > a.value ? b : a);
  return WeeklySummary(total: total, topCategory: top.key, topCategoryAmount: top.value);
}

/// The notification body for [summary].
String weeklySummaryMessage(WeeklySummary summary) {
  final total = formatCurrency(summary.total);
  if (summary.topCategory == null) return 'You spent $total this week.';
  final topAmount = formatCurrency(summary.topCategoryAmount!);
  return 'You spent $total this week. ${summary.topCategory} was your biggest category at $topAmount.';
}
