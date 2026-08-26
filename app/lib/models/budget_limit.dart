class BudgetLimit {
  const BudgetLimit({required this.name, required this.spent, required this.limit});

  final String name;
  final double spent;
  final double limit;

  double get fraction => limit == 0 ? 0 : (spent / limit).clamp(0.0, 1.2);
  bool get isWarning => limit == 0 ? false : (spent / limit) >= 0.9;
}
