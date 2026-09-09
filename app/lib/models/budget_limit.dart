import '../theme/budget_status.dart';

enum BudgetPeriodType {
  weekly,
  monthly,
  yearly,
  custom;

  String get wireValue => name;

  static BudgetPeriodType fromWireValue(String value) =>
      BudgetPeriodType.values.firstWhere((v) => v.wireValue == value);
}

class BudgetLimit {
  const BudgetLimit({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.spent,
    required this.limit,
    required this.periodType,
    required this.periodStart,
    this.periodEnd,
    this.icon = 'tag',
    this.colorIndex,
  });

  final String id;
  final String categoryId;
  final String name;
  final double spent;
  final double limit;
  final BudgetPeriodType periodType;
  final DateTime periodStart;
  final DateTime? periodEnd;
  /// Key into lib/theme/category_icons.dart's curated icon set, joined in
  /// from the category via the `budget_progress` view.
  final String icon;
  /// Index into lib/theme/category_colors.dart's swatch palette, joined
  /// in the same way — see `categoryColorIndexFor`'s fallback for null.
  final int? colorIndex;

  double get fraction => limit == 0 ? 0 : (spent / limit).clamp(0.0, 1.2);
  bool get isWarning => limit > 0 && spent / limit >= 0.9;
  bool get isOverBudget => limit > 0 && spent / limit >= 1.0;
  BudgetStatus get status => budgetStatusForFraction(limit > 0 ? fraction : null);

  factory BudgetLimit.fromRow(Map<String, dynamic> row) => BudgetLimit(
        id: row['budget_id'] as String,
        categoryId: row['category_id'] as String,
        name: row['category_name'] as String,
        spent: double.parse(row['spent'].toString()),
        limit: double.parse(row['limit_amount'].toString()),
        periodType: BudgetPeriodType.fromWireValue(row['period_type'] as String),
        periodStart: DateTime.parse(row['period_start'] as String),
        periodEnd: row['period_end'] == null ? null : DateTime.parse(row['period_end'] as String),
        icon: row['icon'] as String? ?? 'tag',
        colorIndex: row['color_index'] as int?,
      );
}
