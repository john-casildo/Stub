import 'package:flutter/material.dart';
import '../models/budget_limit.dart';
import '../theme/category_colors.dart';
import '../theme/category_icons.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/currency.dart';
import '../util/thousands_input_formatter.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_period_picker.dart';
import '../widgets/stub_pressable.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key, required this.onClose, required this.onSave});

  final VoidCallback onClose;
  final void Function(
    String name,
    double limitAmount,
    BudgetPeriodType periodType,
    DateTime periodStart,
    DateTime? periodEnd,
    String? currencyCode,
    String icon,
    int colorIndex,
  ) onSave;

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  /// Sanity caps, not hard technical limits — long enough for any real
  /// category name/budget, short enough to catch typos and keep the
  /// name legible in chips/rows.
  static const _maxNameLength = 40;
  static const _maxLimitAmount = 10000000000.0;

  final _nameController = TextEditingController();
  final _limitController = TextEditingController();
  BudgetPeriodType _periodType = BudgetPeriodType.monthly;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _currencyCode;
  String _icon = categoryIconKeys.first;
  int _colorIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final limit = double.tryParse(_limitController.text.replaceAll(',', '')) ?? 0;
    if (name.isEmpty) return;
    if (limit > _maxLimitAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Limit can\'t be more than ${formatCurrency(_maxLimitAmount, currencyCode: _currencyCode)}.')),
      );
      return;
    }
    if (_periodType == BudgetPeriodType.custom) {
      if (_customStart == null || _customEnd == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick both a start and end date for a custom period.')),
        );
        return;
      }
      if (_customEnd!.isBefore(_customStart!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End date must be after the start date.')),
        );
        return;
      }
    }
    widget.onSave(
      name,
      limit,
      _periodType,
      _customStart ?? DateTime.now(),
      _customEnd,
      _currencyCode,
      _icon,
      _colorIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: widget.onClose),
        title: Text('New category', style: StubText.archivo(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                maxLength: _maxNameLength,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _limitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [ThousandsSeparatorInputFormatter()],
                decoration: const InputDecoration(labelText: 'Limit'),
              ),
              const SizedBox(height: 20),
              Text('ICON', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink.withValues(alpha: 0.5))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final key in categoryIconKeys)
                    _IconChoice(
                      key: Key('category-icon-$key'),
                      icon: categoryIconData(key),
                      selected: key == _icon,
                      color: categoryColor(_colorIndex, isDark ? Brightness.dark : Brightness.light),
                      onTap: () => setState(() => _icon = key),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('COLOR', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink.withValues(alpha: 0.5))),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < categoryColorCount; i++)
                    _ColorChoice(
                      key: Key('category-color-$i'),
                      color: categoryColor(i, isDark ? Brightness.dark : Brightness.light),
                      selected: i == _colorIndex,
                      onTap: () => setState(() => _colorIndex = i),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('CURRENCY', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink.withValues(alpha: 0.5))),
                  DropdownButton<String?>(
                    value: _currencyCode,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    style: StubText.archivo(fontSize: 14, color: ink),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Default')),
                      for (final code in supportedCurrencies)
                        DropdownMenuItem<String?>(value: code, child: Text(code)),
                    ],
                    onChanged: (code) => setState(() => _currencyCode = code),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              StubPeriodPicker(
                selected: _periodType,
                customStart: _customStart,
                customEnd: _customEnd,
                onTypeChanged: (t) => setState(() => _periodType = t),
                onCustomStartChanged: (d) => setState(() => _customStart = d),
                onCustomEndChanged: (d) => setState(() => _customEnd = d),
              ),
              const SizedBox(height: 24),
              StubButton(label: 'Save category', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({super.key, required this.icon, required this.selected, required this.color, required this.onTap});
  final String icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StubPressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.25), width: selected ? 2 : 1),
        ),
        child: StubIcon(icon, size: 20, color: color),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({super.key, required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ring = isDark ? StubColors.bgDark : StubColors.bgLight;
    return StubPressable(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: selected ? Border.all(color: ring, width: 2) : null,
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)] : null,
        ),
      ),
    );
  }
}
