import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/currency.dart';
import 'stub_icon.dart';

class StubTransactionTile extends StatelessWidget {
  const StubTransactionTile({super.key, required this.transaction, this.onTap});

  final Transaction transaction;
  final VoidCallback? onTap;

  String get _sourceLabel {
    switch (transaction.source) {
      case TransactionSource.receipt:
        return 'RECEIPT';
      case TransactionSource.paymentApp:
        return 'PAYMENT APP';
      case TransactionSource.bankScreenshot:
        return 'BANK SCREEN';
      case TransactionSource.manual:
        return 'MANUAL';
    }
  }

  String get _sourceIconData {
    switch (transaction.source) {
      case TransactionSource.receipt:
        return StubIcons.receipt;
      case TransactionSource.paymentApp:
        return StubIcons.cashBanknote;
      case TransactionSource.bankScreenshot:
        return StubIcons.buildingBank;
      case TransactionSource.manual:
        return StubIcons.pencil;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final surfaceAlt = isDark ? StubColors.surfaceAltDark : StubColors.surfaceAltLight;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: surfaceAlt, borderRadius: BorderRadius.circular(8)),
              child: Center(child: StubIcon(_sourceIconData, size: 17, color: ink.withValues(alpha: 0.7))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.merchant, style: StubText.archivo(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
                  const SizedBox(height: 1),
                  Text('$_sourceLabel · ${transaction.dateLabel}', style: StubText.archivo(fontSize: 11, color: ink.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Text('-${formatCurrency(transaction.amount)}', style: StubText.unbounded(fontSize: 14, color: ink)),
          ],
        ),
      ),
    );
  }
}
