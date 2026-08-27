import '../models/budget_limit.dart';

abstract class BudgetRepository {
  Future<List<BudgetLimit>> list();
  Future<void> create({
    required String categoryId,
    required double limitAmount,
    required BudgetPeriodType periodType,
    required DateTime periodStart,
    DateTime? periodEnd,
  });
}
