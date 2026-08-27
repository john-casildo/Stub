import '../models/transaction.dart';

abstract class TransactionRepository {
  Future<List<Transaction>> list();
  Future<Transaction> create(Transaction transaction);
  Future<void> update(Transaction transaction);
  Future<void> delete(String id);
}
