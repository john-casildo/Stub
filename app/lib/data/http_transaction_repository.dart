import 'api_client.dart';
import 'transaction_repository.dart';
import '../models/transaction.dart';

class HttpTransactionRepository implements TransactionRepository {
  HttpTransactionRepository(this._client);
  final ApiClient _client;

  static const _pageSize = 1000;

  @override
  Future<List<Transaction>> list({int offset = 0}) async {
    final rows = await _client.getList('/transactions?offset=$offset&limit=$_pageSize');
    return rows
        .map((row) => Transaction.fromRow(
              row as Map<String, dynamic>,
              categoryName: row['category_name'] as String,
            ))
        .toList();
  }

  @override
  Future<Transaction> create(Transaction transaction) async {
    final row = await _client.post('/transactions', _toWireBody(transaction));
    return Transaction.fromRow(row, categoryName: row['category_name'] as String);
  }

  @override
  Future<void> update(Transaction transaction) =>
      _client.patch('/transactions/${transaction.id}', _toWireBody(transaction));

  @override
  Future<void> delete(String id) => _client.delete('/transactions/$id');

  /// `toInsertRow` already builds exactly the fields the server route
  /// needs (see `server/src/routes/transactions.ts`); the `userId` passed
  /// here is discarded — the server derives the real owner from the JWT,
  /// never from client-supplied data.
  Map<String, dynamic> _toWireBody(Transaction transaction) {
    final row = transaction.toInsertRow(userId: 'unused');
    return {
      'categoryId': row['category_id'],
      'merchant': row['merchant'],
      'amount': row['amount'],
      'source': row['source'],
      'occurredAt': row['occurred_at'],
    };
  }
}
