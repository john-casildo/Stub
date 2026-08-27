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
  });

  final String id;
  final String categoryId;
  final String name;
  final double spent;
  final double limit;
  final BudgetPeriodType periodType;
  final DateTime periodStart;
  final DateTime? periodEnd;

  double get fraction => limit == 0 ? 0 : (spent / limit).clamp(0.0, 1.2);
  bool get isWarning => limit > 0 && spent / limit >= 0.9;

  factory BudgetLimit.fromRow(Map<String, dynamic> row) => BudgetLimit(
        id: row['budget_id'] as String,
        categoryId: row['category_id'] as String,
        name: row['category_name'] as String,
        spent: double.parse(row['spent'].toString()),
        limit: double.parse(row['limit_amount'].toString()),
        periodType: BudgetPeriodType.fromWireValue(row['period_type'] as String),
        periodStart: DateTime.parse(row['period_start'] as String),
        periodEnd: row['period_end'] == null ? null : DateTime.parse(row['period_end'] as String),
      );
}
