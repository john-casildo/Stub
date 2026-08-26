import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_icon.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({
    super.key,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.onClose,
    required this.onAddToLedger,
  });

  final String merchant;
  final double amount;
  final String category;
  final VoidCallback onClose;
  final VoidCallback onAddToLedger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final good = isDark ? StubColors.goodDark : StubColors.goodLight;
    final goodBg = good.withValues(alpha: 0.14);

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: onClose),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              StubCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, color: good, size: 28),
                    const SizedBox(height: 12),
                    _row('MERCHANT', merchant, ink, ink50),
                    _row('AMOUNT', '\$${amount.toStringAsFixed(2)}', ink, ink50, mono: true),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: goodBg, borderRadius: BorderRadius.circular(100)),
                      child: Text(category, style: StubText.archivo(fontSize: 12, fontWeight: FontWeight.w600, color: good)),
                    ),
                    const SizedBox(height: 16),
                    StubButton(label: 'Add to ledger', onPressed: onAddToLedger),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color ink, Color ink50, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: StubText.archivo(fontSize: 11, color: ink50)),
          Text(
            value,
            style: mono
                ? StubText.unbounded(fontSize: 14, color: ink)
                : StubText.archivo(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
          ),
        ],
      ),
    );
  }
}
