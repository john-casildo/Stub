import 'package:flutter/material.dart';
import '../models/budget_limit.dart';
import 'stub_chip.dart';
import 'stub_field_row.dart';

class StubPeriodPicker extends StatelessWidget {
  const StubPeriodPicker({
    super.key,
    required this.selected,
    required this.customStart,
    required this.customEnd,
    required this.onTypeChanged,
    required this.onCustomStartChanged,
    required this.onCustomEndChanged,
  });

  final BudgetPeriodType selected;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ValueChanged<BudgetPeriodType> onTypeChanged;
  final ValueChanged<DateTime> onCustomStartChanged;
  final ValueChanged<DateTime> onCustomEndChanged;

  static const _labels = {
    BudgetPeriodType.weekly: 'Weekly',
    BudgetPeriodType.monthly: 'Monthly',
    BudgetPeriodType.yearly: 'Yearly',
    BudgetPeriodType.custom: 'Custom',
  };

  Future<void> _pickDate(BuildContext context, DateTime? initial, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  String _formatDate(DateTime? d) => d == null ? 'Select date' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in BudgetPeriodType.values)
              StubChip(label: _labels[type]!, selected: type == selected, onTap: () => onTypeChanged(type)),
          ],
        ),
        if (selected == BudgetPeriodType.custom) ...[
          const SizedBox(height: 8),
          StubFieldRow(
            label: 'Start date',
            value: _formatDate(customStart),
            onTap: () => _pickDate(context, customStart, onCustomStartChanged),
          ),
          StubFieldRow(
            label: 'End date',
            value: _formatDate(customEnd),
            onTap: () => _pickDate(context, customEnd, onCustomEndChanged),
          ),
        ],
      ],
    );
  }
}
