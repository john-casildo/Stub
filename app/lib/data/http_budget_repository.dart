import 'api_client.dart';
import 'budget_repository.dart';
import '../models/budget_limit.dart';

class HttpBudgetRepository implements BudgetRepository {
  HttpBudgetRepository(this._client);
  final ApiClient _client;

  @override
  Future<List<BudgetLimit>> list() async {
    final rows = await _client.getList('/budgets');
    return rows.map((row) => BudgetLimit.fromRow(row as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> create({
    required String categoryId,
    required double limitAmount,
    required BudgetPeriodType periodType,
    required DateTime periodStart,
    DateTime? periodEnd,
  }) {
    return _client.post('/budgets', {
      'categoryId': categoryId,
      'limitAmount': limitAmount,
      'periodType': periodType.wireValue,
      'periodStart': periodStart.toIso8601String().split('T').first,
      if (periodEnd != null) 'periodEnd': periodEnd.toIso8601String().split('T').first,
    });
  }
}
