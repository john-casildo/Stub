import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/currency.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_chip.dart';
import '../widgets/stub_field_row.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_pressable.dart';

class EditEntryScreen extends StatefulWidget {
  const EditEntryScreen({
    super.key,
    this.isCreating = false,
    required this.merchant,
    required this.amount,
    required this.categories,
    required this.selectedCategory,
    required this.sourceLabel,
    required this.onClose,
    required this.onSave,
    this.onDelete,
  });

  final bool isCreating;
  final String merchant;
  final double amount;
  final List<String> categories;
  final String selectedCategory;
  final String sourceLabel;
  final VoidCallback onClose;
  final void Function(String merchant, double amount, String category) onSave;
  final VoidCallback? onDelete;

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  late String _selected = widget.selectedCategory;
  late String _merchant = widget.merchant;
  late double _amount = widget.amount;

  Future<void> _editMerchant() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditFieldDialog(title: 'Merchant', initial: _merchant),
    );
    if (result != null) setState(() => _merchant = result);
  }

  Future<void> _editAmount() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Amount',
        initial: _amount.toStringAsFixed(2),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
    if (result != null) {
      final parsed = double.tryParse(result);
      if (parsed != null) setState(() => _amount = parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final danger = isDark ? StubColors.dangerDark : StubColors.dangerLight;

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: widget.onClose),
        title: Text('Edit entry', style: StubText.archivo(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StubFieldRow(label: 'Merchant', value: _merchant, editable: true, onTap: _editMerchant),
              StubFieldRow(
                label: 'Amount',
                value: formatCurrency(_amount),
                mono: true,
                editable: true,
                onTap: _editAmount,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CATEGORY', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink.withValues(alpha: 0.5))),
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
              StubFieldRow(label: 'Source', value: widget.sourceLabel, valueColor: ink.withValues(alpha: 0.6)),
              const SizedBox(height: 22),
              StubButton(
                label: 'Save changes',
                variant: StubButtonVariant.save,
                onPressed: () => widget.onSave(_merchant, _amount, _selected),
              ),
              if (!widget.isCreating) ...[
                const SizedBox(height: 12),
                Center(
                  child: StubPressable(
                    onTap: widget.onDelete,
                    ensureMinTapSize: true,
                    child: Text('Delete entry', style: StubText.archivo(fontSize: 13, fontWeight: FontWeight.w600, color: danger)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditFieldDialog extends StatefulWidget {
  const _EditFieldDialog({required this.title, required this.initial, this.keyboardType});
  final String title;
  final String initial;
  final TextInputType? keyboardType;

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(controller: _controller, autofocus: true, keyboardType: widget.keyboardType),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Save')),
      ],
    );
  }
}
