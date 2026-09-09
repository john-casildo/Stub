import 'package:flutter/material.dart';
import '../data/local_prefs.dart';
import '../data/notification_service.dart';
import '../util/currency.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_chip.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_loading_indicator.dart';

/// Settings screen — theme picker, notification toggles (both real:
/// "Budget limit warnings" via real-time local notifications, "Weekly
/// summary" via a background task), data export/delete slots, and a
/// placeholder account-deletion row.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.localPrefs,
    required this.themeModeNotifier,
    required this.currencyNotifier,
    required this.lockEnabledNotifier,
    required this.lockSupported,
    required this.notificationService,
    required this.onWeeklySummaryToggled,
    required this.onClose,
    required this.onExportData,
    required this.onDeleteAllData,
  });

  final LocalPrefs localPrefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<String> currencyNotifier;
  final ValueNotifier<bool> lockEnabledNotifier;
  /// Whether this device has any biometric/passcode enrolled at all —
  /// the Face ID/passcode toggle is hidden entirely when false.
  final bool lockSupported;
  final NotificationService notificationService;
  /// Registers/cancels the real weekly-summary background task —
  /// separate from `NotificationService` because it drives `workmanager`
  /// directly, which (unlike `NotificationService`) has no fake and
  /// can't run inside a widget test.
  final Future<void> Function(bool enabled) onWeeklySummaryToggled;
  final VoidCallback onClose;
  final VoidCallback onExportData;
  final VoidCallback onDeleteAllData;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode? _themeMode;
  String? _currencyCode;
  bool? _budgetWarnings;
  bool? _weeklySummary;
  bool? _lockEnabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// If `SharedPreferences` throws (a real failure mode — see
  /// `_ThrowingSharedPreferencesStore` in `test/widget_test.dart`, built for
  /// the identical bug in `_LockGate`), fall back to the same defaults
  /// `LocalPrefs`'s own getters use rather than leaving `_themeMode` null
  /// forever, which would strand this screen on its loading state with no
  /// way out.
  Future<void> _load() async {
    ThemeMode theme = ThemeMode.system;
    String currency = CurrencyConfig.code;
    bool warnings = true;
    bool summary = true;
    bool lock = true;
    try {
      theme = await widget.localPrefs.themeMode();
      currency = await widget.localPrefs.currencyCode();
      warnings = await widget.localPrefs.budgetWarningsEnabled();
      summary = await widget.localPrefs.weeklySummaryEnabled();
      lock = await widget.localPrefs.lockEnabled();
    } catch (_) {
      // Fall through with the defaults above — still lets the screen render.
    }
    if (!mounted) return;
    setState(() {
      _themeMode = theme;
      _currencyCode = currency;
      _budgetWarnings = warnings;
      _weeklySummary = summary;
      _lockEnabled = lock;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    widget.themeModeNotifier.value = mode;
    try {
      await widget.localPrefs.setThemeMode(mode);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save that setting. Please try again.')),
        );
      }
    }
  }

  Future<void> _setCurrencyCode(String code) async {
    setState(() => _currencyCode = code);
    widget.currencyNotifier.value = code;
    try {
      await widget.localPrefs.setCurrencyCode(code);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save that setting. Please try again.')),
        );
      }
    }
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

    final appBar = AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: widget.onClose),
      title: Text('Settings', style: StubText.archivo(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
      centerTitle: true,
    );

    if (_themeMode == null) {
      // Same app bar as the loaded state below (with its working close
      // button) so a slow or failed load never stranded the user on a bare
      // spinner with no way to back out.
      return Scaffold(
        backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
        appBar: appBar,
        body: const Center(child: StubLoadingIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: appBar,
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
              Text('CURRENCY', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: _currencyCode,
                isDense: true,
                underline: const SizedBox.shrink(),
                dropdownColor: isDark ? StubColors.bgDark : StubColors.bgLight,
                style: StubText.archivo(fontSize: 14, color: ink),
                items: [
                  for (final code in supportedCurrencies)
                    DropdownMenuItem(value: code, child: Text(code)),
                ],
                onChanged: (code) {
                  if (code != null) _setCurrencyCode(code);
                },
              ),
              if (widget.lockSupported) ...[
                const SizedBox(height: 24),
                Text('SECURITY', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Require Face ID / Passcode', style: StubText.archivo(fontSize: 14, color: ink)),
                  value: _lockEnabled ?? true,
                  activeThumbColor: (isDark ? StubColors.goodDark : StubColors.goodLight),
                  onChanged: (value) async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _lockEnabled = value);
                    widget.lockEnabledNotifier.value = value;
                    try {
                      await widget.localPrefs.setLockEnabled(value);
                    } catch (_) {
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Could not save that setting. Please try again.')),
                        );
                      }
                    }
                  },
                ),
              ],
              const SizedBox(height: 24),
              Text('NOTIFICATIONS', style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
              const SizedBox(height: 10),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Budget limit warnings', style: StubText.archivo(fontSize: 14, color: ink)),
                value: _budgetWarnings ?? true,
                activeThumbColor: (isDark ? StubColors.goodDark : StubColors.goodLight),
                onChanged: (value) async {
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _budgetWarnings = value);
                  try {
                    await widget.localPrefs.setBudgetWarningsEnabled(value);
                  } catch (_) {
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Could not save that setting. Please try again.')),
                      );
                    }
                    return;
                  }
                  if (value) {
                    final granted = await widget.notificationService.requestPermission();
                    if (!granted && mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text("Notifications are blocked in your device settings — enable them there to get alerts."),
                        ),
                      );
                    }
                  }
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Weekly summary', style: StubText.archivo(fontSize: 14, color: ink)),
                value: _weeklySummary ?? true,
                activeThumbColor: (isDark ? StubColors.goodDark : StubColors.goodLight),
                onChanged: (value) async {
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _weeklySummary = value);
                  try {
                    await widget.localPrefs.setWeeklySummaryEnabled(value);
                  } catch (_) {
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Could not save that setting. Please try again.')),
                      );
                    }
                    return;
                  }
                  if (value) {
                    final granted = await widget.notificationService.requestPermission();
                    if (!granted && mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text("Notifications are blocked in your device settings — enable them there to get alerts."),
                        ),
                      );
                    }
                  }
                  try {
                    await widget.onWeeklySummaryToggled(value);
                  } catch (_) {
                    // Best-effort — the preference itself already saved
                    // above; a registration failure just means the
                    // background task doesn't (yet) reflect it.
                  }
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
