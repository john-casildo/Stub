import 'package:flutter/material.dart';
import '../data/local_prefs.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_chip.dart';
import '../widgets/stub_icon.dart';

/// Settings screen — theme picker, notification toggles (not yet wired to
/// real notifications), data export/delete slots (wired in Tasks 5/6), and
/// a placeholder account-deletion row.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.localPrefs,
    required this.themeModeNotifier,
    required this.onClose,
    required this.onExportData,
    required this.onDeleteAllData,
  });

  final LocalPrefs localPrefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final VoidCallback onClose;
  final VoidCallback onExportData;
  final VoidCallback onDeleteAllData;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode? _themeMode;
  bool? _budgetWarnings;
  bool? _weeklySummary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final theme = await widget.localPrefs.themeMode();
    final warnings = await widget.localPrefs.budgetWarningsEnabled();
    final summary = await widget.localPrefs.weeklySummaryEnabled();
    if (!mounted) return;
    setState(() {
      _themeMode = theme;
      _budgetWarnings = warnings;
      _weeklySummary = summary;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    widget.themeModeNotifier.value = mode;
    await widget.localPrefs.setThemeMode(mode);
  }

  Future<void> _confirmDeleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text('This will permanently delete every transaction, category, and budget. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDeleteAllData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final danger = isDark ? StubColors.dangerDark : StubColors.dangerLight;

    if (_themeMode == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: widget.onClose),
        title: Text('Settings', style: StubText.archivo(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('THEME', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  StubChip(label: 'Light', selected: _themeMode == ThemeMode.light, onTap: () => _setThemeMode(ThemeMode.light)),
                  StubChip(label: 'Dark', selected: _themeMode == ThemeMode.dark, onTap: () => _setThemeMode(ThemeMode.dark)),
                  StubChip(label: 'System', selected: _themeMode == ThemeMode.system, onTap: () => _setThemeMode(ThemeMode.system)),
                ],
              ),
              const SizedBox(height: 24),
              Text('NOTIFICATIONS', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
              const SizedBox(height: 4),
              Text(
                "These toggles are not yet wired up — they don't do anything today.",
                style: StubText.archivo(fontSize: 12, color: ink50),
              ),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Budget limit warnings', style: StubText.archivo(fontSize: 14, color: ink)),
                value: _budgetWarnings ?? true,
                activeThumbColor: (isDark ? StubColors.goodDark : StubColors.goodLight),
                onChanged: (value) async {
                  setState(() => _budgetWarnings = value);
                  await widget.localPrefs.setBudgetWarningsEnabled(value);
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Weekly summary', style: StubText.archivo(fontSize: 14, color: ink)),
                value: _weeklySummary ?? true,
                activeThumbColor: (isDark ? StubColors.goodDark : StubColors.goodLight),
                onChanged: (value) async {
                  setState(() => _weeklySummary = value);
                  await widget.localPrefs.setWeeklySummaryEnabled(value);
                },
              ),
              const SizedBox(height: 24),
              Text('DATA', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
              const SizedBox(height: 10),
              StubButton(label: 'Export data', onPressed: widget.onExportData),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _confirmDeleteAllData,
                style: OutlinedButton.styleFrom(foregroundColor: danger, side: BorderSide(color: danger)),
                child: const Text('Delete all data'),
              ),
              const SizedBox(height: 24),
              Text('ACCOUNT', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
              const SizedBox(height: 10),
              StubCard(
                child: Row(
                  children: [
                    Expanded(child: Text('Delete account', style: StubText.archivo(fontSize: 14, color: ink.withValues(alpha: 0.3)))),
                    Text('Coming soon', style: StubText.archivo(fontSize: 12, color: ink.withValues(alpha: 0.4))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
