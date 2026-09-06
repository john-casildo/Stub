import '../models/transaction.dart';

abstract class TransactionRepository {
  /// Returns one page of transactions starting at [offset]. Implementations
  /// backed by a server with a row cap (PostgREST's `max_rows`, see
  /// `SupabaseTransactionRepository`) return at most one page's worth per
  /// call — callers that need the *entire* list (e.g. CSV export) must loop,
  /// advancing [offset] by the number of rows returned, until an empty page
  /// comes back.
  Future<List<Transaction>> list({int offset = 0});
  Future<Transaction> create(Transaction transaction);
  Future<void> update(Transaction transaction);
  Future<void> delete(String id);
}
