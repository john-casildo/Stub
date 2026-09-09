import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/currency.dart';
import '../util/thousands_input_formatter.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_chip.dart';
import '../widgets/stub_field_row.dart';
import '../widgets/stub_icon.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({
    super.key,
    required this.categories,
    required this.onClose,
    required this.onSave,
    this.initialAmount,
    this.initialMerchant,
  });

  final List<String> categories;
  final VoidCallback onClose;
  final void Function(double amount, String merchant, String category) onSave;
  /// Pre-fills the amount/merchant fields — used when this screen is
  /// opened from a Siri Shortcuts quick-log deep link (see
  /// `RootShell`'s `initialManualEntryAmount`/`initialManualEntryMerchant`).
  /// Both null in every other entry point into this screen.
  final double? initialAmount;
  final String? initialMerchant;

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  /// Same sanity cap as `AddCategoryScreen`'s limit field — not a
  /// technical limit, just generous enough for any real transaction
  /// while catching typos.
  static const _maxAmount = 10000000000.0;

  late final _amountController = TextEditingController(
    text: widget.initialAmount == null ? '0.00' : widget.initialAmount!.toStringAsFixed(2),
  );
  late final _merchantController = TextEditingController(text: widget.initialMerchant ?? '');
  late String _selected = widget.categories.first;

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink30 = ink.withValues(alpha: 0.3);

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: widget.onClose),
        title: Text('New entry', style: StubText.archivo(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    IntrinsicWidth(
                      // Blue is a gradient everywhere per DESIGN.md, including
                      // this editable amount — ShaderMask over the whole
                      // TextField (same technique as stub_bottom_nav.dart's
                      // active label) so digits, cursor, and the "$" prefix
                      // all pick up StubColors.gradPop.
                      child: ShaderMask(
                        shaderCallback: (rect) => StubColors.gradPop(brightness).createShader(rect),
                        child: TextField(
                          controller: _amountController,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [ThousandsSeparatorInputFormatter()],
                          style: StubText.unbounded(fontSize: 32, color: Colors.white),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixText: '\$',
                            prefixStyle: StubText.unbounded(fontSize: 32, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Text('tap to type an amount', style: StubText.archivo(fontSize: 11, letterSpacing: 0.5, color: ink30)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StubFieldRow(
                label: 'Merchant',
                value: _merchantController.text.isEmpty ? 'Add a name' : _merchantController.text,
                valueColor: _merchantController.text.isEmpty ? ink30 : null,
                onTap: () async {
                  final name = await showDialog<String>(
                    context: context,
                    builder: (context) => _MerchantDialog(initial: _merchantController.text),
                  );
                  if (name != null) setState(() => _merchantController.text = name);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CATEGORY', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink30)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in widget.categories)
                          StubChip(label: c, selected: c == _selected, onTap: () => setState(() => _selected = c)),
                      ],
                    ),
                  ],
                ),
              ),
              StubFieldRow(label: 'Source', value: 'Manual · cash', valueColor: ink.withValues(alpha: 0.6)),
              const SizedBox(height: 20),
              StubButton(
                label: 'Save entry',
                variant: StubButtonVariant.save,
                onPressed: () {
                  final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
                  if (amount > _maxAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Amount can\'t be more than ${formatCurrency(_maxAmount)}.')),
                    );
                    return;
                  }
                  widget.onSave(amount, _merchantController.text, _selected);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MerchantDialog extends StatefulWidget {
  const _MerchantDialog({required this.initial});
  final String initial;

  @override
  State<_MerchantDialog> createState() => _MerchantDialogState();
}

class _MerchantDialogState extends State<_MerchantDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Merchant name'),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Save')),
      ],
    );
  }
}
