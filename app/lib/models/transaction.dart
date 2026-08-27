enum TransactionSource { receipt, paymentApp, bankScreenshot, manual }

class Transaction {
  const Transaction({
    required this.id,
    required this.categoryId,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.source,
    required this.occurredAt,
  });

  final String id;
  final String categoryId;
  final String merchant;
  final double amount;
  final String category;
  final TransactionSource source;
  final DateTime occurredAt;

  String get dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(occurredAt.year, occurredAt.month, occurredAt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (diff < 7) return weekdays[occurredAt.weekday - 1];
    return '${occurredAt.month}/${occurredAt.day}';
  }

  static String _wireSource(TransactionSource source) => switch (source) {
        TransactionSource.receipt => 'receipt',
        TransactionSource.paymentApp => 'payment_app',
        TransactionSource.bankScreenshot => 'bank_screenshot',
        TransactionSource.manual => 'manual',
      };

  static TransactionSource _sourceFromWire(String value) => switch (value) {
        'receipt' => TransactionSource.receipt,
        'payment_app' => TransactionSource.paymentApp,
        'bank_screenshot' => TransactionSource.bankScreenshot,
        'manual' => TransactionSource.manual,
        _ => throw ArgumentError('Unknown transaction source: $value'),
      };

  factory Transaction.fromRow(Map<String, dynamic> row, {required String categoryName}) => Transaction(
        id: row['id'] as String,
        categoryId: row['category_id'] as String,
        merchant: row['merchant'] as String,
        amount: double.parse(row['amount'].toString()),
        category: categoryName,
        source: _sourceFromWire(row['source'] as String),
        occurredAt: DateTime.parse(row['occurred_at'] as String),
      );

  Map<String, dynamic> toInsertRow({required String userId}) => {
        'user_id': userId,
        'category_id': categoryId,
        'merchant': merchant,
        'amount': amount,
        'source': _wireSource(source),
        'occurred_at': occurredAt.toIso8601String(),
      };

  Transaction copyWith({String? merchant, double? amount, String? categoryId, String? category}) => Transaction(
        id: id,
        categoryId: categoryId ?? this.categoryId,
        merchant: merchant ?? this.merchant,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        source: source,
        occurredAt: occurredAt,
      );
}
