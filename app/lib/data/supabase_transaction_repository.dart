import 'package:supabase_flutter/supabase_flutter.dart';
import 'transaction_repository.dart';
import '../models/transaction.dart';

class SupabaseTransactionRepository implements TransactionRepository {
  SupabaseTransactionRepository(this._client);
  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Transaction>> list() async {
    final rows = await _client
        .from('transactions')
        .select('*, categories(name)')
        .order('occurred_at', ascending: false);
    return rows
        .map((row) => Transaction.fromRow(row, categoryName: row['categories']['name'] as String))
        .toList();
  }

  @override
  Future<Transaction> create(Transaction transaction) async {
    final row = await _client
        .from('transactions')
        .insert(transaction.toInsertRow(userId: _userId))
        .select('*, categories(name)')
        .single();
    return Transaction.fromRow(row, categoryName: row['categories']['name'] as String);
  }

  @override
  Future<void> update(Transaction transaction) async {
    await _client.from('transactions').update(transaction.toInsertRow(userId: _userId)).eq('id', transaction.id);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }
}
