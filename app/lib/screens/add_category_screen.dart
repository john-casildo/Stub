import 'package:flutter/material.dart';
import '../models/budget_limit.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/currency.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_period_picker.dart';

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
  ) onSave;

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _nameController = TextEditingController();
  final _limitController = TextEditingController();
  BudgetPeriodType _periodType = BudgetPeriodType.monthly;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _currencyCode;

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final limit = double.tryParse(_limitController.text) ?? 0;
    if (name.isEmpty) return;
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
    widget.onSave(name, limit, _periodType, _customStart ?? DateTime.now(), _customEnd, _currencyCode);
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
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Category name')),
              const SizedBox(height: 16),
              TextField(
                controller: _limitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monthly limit'),
              ),
              const SizedBox(height: 20),
              Text('CURRENCY', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink.withValues(alpha: 0.5))),
              const SizedBox(height: 10),
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
