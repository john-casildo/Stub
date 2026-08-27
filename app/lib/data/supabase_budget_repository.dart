import 'package:supabase_flutter/supabase_flutter.dart';
import 'budget_repository.dart';
import '../models/budget_limit.dart';

class SupabaseBudgetRepository implements BudgetRepository {
  SupabaseBudgetRepository(this._client);
  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<BudgetLimit>> list() async {
    final rows = await _client.from('budget_progress').select();
    return rows.map((row) => BudgetLimit.fromRow(row)).toList();
  }

  @override
  Future<void> create({
    required String categoryId,
    required double limitAmount,
    required BudgetPeriodType periodType,
    required DateTime periodStart,
    DateTime? periodEnd,
  }) async {
    await _client.from('budgets').insert({
      'user_id': _userId,
      'category_id': categoryId,
      'limit_amount': limitAmount,
      'period_type': periodType.wireValue,
      'period_start': periodStart.toIso8601String().split('T').first,
      if (periodEnd != null) 'period_end': periodEnd.toIso8601String().split('T').first,
    });
  }
}
