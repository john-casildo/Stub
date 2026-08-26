enum TransactionSource { receipt, paymentApp, bankScreenshot, manual }

class Transaction {
  const Transaction({
    required this.merchant,
    required this.amount,
    required this.category,
    required this.source,
    required this.dateLabel,
  });

  final String merchant;
  final double amount;
  final String category;
  final TransactionSource source;
  final String dateLabel;
}
