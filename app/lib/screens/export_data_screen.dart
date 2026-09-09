import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_chip.dart';
import '../widgets/stub_icon.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// A distinct year+month, used both as the picker's option list and as
/// the export filter — equality/hashCode by (year, month) so it works as
/// a plain value in a `DropdownButton`/`Set`.
class ExportMonth {
  const ExportMonth(this.year, this.month);
  final int year;
  final int month;

  String get label => '${_monthNames[month - 1]} $year';
  bool matches(DateTime date) => date.year == year && date.month == month;

  @override
  bool operator ==(Object other) => other is ExportMonth && other.year == year && other.month == month;
  @override
  int get hashCode => Object.hash(year, month);
}

/// Lets the user narrow a CSV export to one month (or all time) and a
/// subset of categories, instead of always exporting every transaction
/// ever with no way to scope it down. Reachable from `SettingsScreen`'s
/// "Export data" button via `RootShell`.
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({
    super.key,
    required this.transactions,
    required this.categoryNames,
    required this.onClose,
    required this.onExport,
  });

  /// The full (already-paginated-through) transaction list — used only
  /// to compute which months actually have data for the picker.
  final List<Transaction> transactions;
  final List<String> categoryNames;
  final VoidCallback onClose;
  /// [month] null means "all time". [categoryNames] is never empty when
  /// this fires — the button that calls it is disabled otherwise.
  final void Function(ExportMonth? month, Set<String> categoryNames) onExport;

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  late final List<ExportMonth> _months = _distinctMonths(widget.transactions);
  late ExportMonth? _selectedMonth = _months.isNotEmpty ? _months.first : null;
  late final Set<String> _selectedCategories = widget.categoryNames.toSet();

  static List<ExportMonth> _distinctMonths(List<Transaction> transactions) {
    final months = <ExportMonth>{};
    for (final t in transactions) {
      months.add(ExportMonth(t.occurredAt.year, t.occurredAt.month));
    }
    final sorted = months.toList()
      ..sort((a, b) => b.year != a.year ? b.year.compareTo(a.year) : b.month.compareTo(a.month));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: widget.onClose),
        title: Text('Export data', style: StubText.archivo(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MONTH', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
              const SizedBox(height: 10),
              DropdownButton<ExportMonth?>(
                value: _selectedMonth,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: StubText.archivo(fontSize: 14, color: ink),
                items: [
                  const DropdownMenuItem<ExportMonth?>(value: null, child: Text('All time')),
                  for (final m in _months) DropdownMenuItem<ExportMonth?>(value: m, child: Text(m.label)),
                ],
                onChanged: (m) => setState(() => _selectedMonth = m),
              ),
              const SizedBox(height: 20),
              Text('CATEGORIES', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in widget.categoryNames)
                    StubChip(
                      label: name,
                      selected: _selectedCategories.contains(name),
                      onTap: () => setState(() {
                        if (_selectedCategories.contains(name)) {
                          _selectedCategories.remove(name);
                        } else {
                          _selectedCategories.add(name);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              StubButton(
                label: 'Export CSV',
                onPressed: _selectedCategories.isEmpty
                    ? null
                    : () => widget.onExport(_selectedMonth, _selectedCategories),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
