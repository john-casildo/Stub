import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _sourceLabel(TransactionSource source) => switch (source) {
      TransactionSource.receipt => 'Receipt',
      TransactionSource.paymentApp => 'Payment app',
      TransactionSource.bankScreenshot => 'Bank screenshot',
      TransactionSource.manual => 'Manual',
    };

/// Pure, fully unit-testable — no platform/file dependency.
String buildTransactionsCsv(List<Transaction> transactions) {
  final buffer = StringBuffer('Date,Merchant,Amount,Category,Source\n');
  for (final t in transactions) {
    final date =
        '${t.occurredAt.year}-${t.occurredAt.month.toString().padLeft(2, '0')}-${t.occurredAt.day.toString().padLeft(2, '0')}';
    buffer.writeln([
      date,
      _csvField(t.merchant),
      t.amount.toStringAsFixed(2),
      _csvField(t.category),
      _sourceLabel(t.source),
    ].join(','));
  }
  return buffer.toString();
}

/// Writes the CSV to a temp file and hands it to the OS share sheet.
/// Not unit-tested — verify manually per this task's brief.
Future<void> exportTransactionsCsv(List<Transaction> transactions) async {
  final csv = buildTransactionsCsv(transactions);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/stub_transactions.csv');
  await file.writeAsString(csv);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: 'Stub transactions export'),
  );
}
