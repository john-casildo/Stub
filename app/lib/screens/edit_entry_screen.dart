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
    required this.merchant,
    required this.amount,
    required this.categories,
    required this.selectedCategory,
    required this.sourceLabel,
    required this.onClose,
    required this.onSave,
    required this.onDelete,
  });

  final String merchant;
  final double amount;
  final List<String> categories;
  final String selectedCategory;
  final String sourceLabel;
  final VoidCallback onClose;
  final ValueChanged<String> onSave;
  final VoidCallback onDelete;

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  late String _selected = widget.selectedCategory;

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
              StubFieldRow(label: 'Merchant', value: widget.merchant, editable: true),
              StubFieldRow(label: 'Amount', value: formatCurrency(widget.amount), mono: true, editable: true),
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
              StubButton(label: 'Save changes', variant: StubButtonVariant.save, onPressed: () => widget.onSave(_selected)),
              const SizedBox(height: 12),
              Center(
                child: StubPressable(
                  onTap: widget.onDelete,
                  ensureMinTapSize: true,
                  child: Text('Delete entry', style: StubText.archivo(fontSize: 13, fontWeight: FontWeight.w600, color: danger)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
