# Profile & Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Profile tab gap with a real `ProfileScreen` (identity/account status via the now-existing `AccountLinkService`, lifetime stats, entry to Settings) and a `SettingsScreen` (theme, notification toggles, CSV export, delete-all-data, a disabled "delete account" row).

**Architecture:** Two new screens following the app's established pattern (pure presentational widgets, data/callbacks supplied by `RootShell`). Theme becomes live-reactive via a `ValueNotifier<ThemeMode>` created in `main.dart` and threaded down to `SettingsScreen`. `LocalPrefs` (already exists) gains theme and notification-toggle persistence. `AccountLinkService` (already exists) gains a `memberSince` getter. Profile's account section reuses `StubAccountLinkPanel` (already exists from the account-linking plan) exactly as that plan's design spec intended.

**Tech Stack:** Flutter/Dart, `supabase_flutter`, `shared_preferences` (already a dependency), new dependencies `share_plus` + `path_provider` (CSV export via the OS share sheet).

**Spec:** `docs/superpowers/specs/2026-08-27-profile-and-settings-design.md`

## Global Constraints

- No HTML mockup step — designed and built directly in Flutter, reusing DESIGN.md's existing component system.
- Theme and notification preferences persist locally via `shared_preferences` (device-level UI settings, not financial data) — never synced through Supabase.
- Notification toggles are functionally inert — no notification system exists anywhere in this app. The UI must say so explicitly.
- "Delete account" is a disabled/"coming soon" row — not implemented (needs a Supabase Edge Function with the service-role key, out of scope).
- Export format is CSV (date, merchant, amount, category, source — one row per transaction), delivered as an actual file via the OS share sheet (`SharePlus.instance.share(ShareParams(files: [XFile(...)]))`), not shared as plain text.
- `flutter analyze` clean and the full `flutter test` suite green before every commit.
- Testing strategy matches this project's established pattern: pure logic (CSV building, `LocalPrefs`/`AccountLinkService` extensions) gets unit tests; screens are tested against fakes; anything that genuinely requires the OS share sheet or a real device is out of automated-test scope and gets a manual-verification note instead.

---

### Task 1: LocalPrefs — theme mode and notification-toggle persistence

**Files:**
- Modify: `app/lib/data/local_prefs.dart`
- Test: `app/test/data/local_prefs_test.dart` (extend existing file)

**Interfaces:**
- Produces: `LocalPrefs` gains `Future<ThemeMode> themeMode()`, `Future<void> setThemeMode(ThemeMode value)`, `Future<bool> budgetWarningsEnabled()`, `Future<void> setBudgetWarningsEnabled(bool value)`, `Future<bool> weeklySummaryEnabled()`, `Future<void> setWeeklySummaryEnabled(bool value)`.
- Consumes: `package:flutter/material.dart`'s `ThemeMode` enum (light/dark/system — matches this feature's needs exactly, no need for a separate custom enum).

- [ ] **Step 1: Write the failing tests**

```dart
// Add to app/test/data/local_prefs_test.dart

test('themeMode defaults to system, then persists the set value', () async {
  final prefs = LocalPrefs();
  expect(await prefs.themeMode(), ThemeMode.system);

  await prefs.setThemeMode(ThemeMode.dark);
  expect(await prefs.themeMode(), ThemeMode.dark);
});

test('budgetWarningsEnabled defaults to true, then persists the set value', () async {
  final prefs = LocalPrefs();
  expect(await prefs.budgetWarningsEnabled(), isTrue);

  await prefs.setBudgetWarningsEnabled(false);
  expect(await prefs.budgetWarningsEnabled(), isFalse);
});

test('weeklySummaryEnabled defaults to true, then persists the set value', () async {
  final prefs = LocalPrefs();
  expect(await prefs.weeklySummaryEnabled(), isTrue);

  await prefs.setWeeklySummaryEnabled(false);
  expect(await prefs.weeklySummaryEnabled(), isFalse);
});
```

(These tests share the existing file's `setUp(() { SharedPreferences.setMockInitialValues({}); })` — no new setup needed.)

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/data/local_prefs_test.dart
```

- [ ] **Step 3: Implement**

Add to `app/lib/data/local_prefs.dart` (keep the existing `hasSeenBackupPrompt`/`setHasSeenBackupPrompt` methods and their key untouched):

```dart
import 'package:flutter/material.dart';
// ...existing imports...

class LocalPrefs {
  static const _hasSeenBackupPromptKey = 'has_seen_backup_prompt';
  static const _themeModeKey = 'theme_mode';
  static const _budgetWarningsEnabledKey = 'budget_warnings_enabled';
  static const _weeklySummaryEnabledKey = 'weekly_summary_enabled';

  // ...existing hasSeenBackupPrompt/setHasSeenBackupPrompt methods unchanged...

  Future<ThemeMode> themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere((v) => v.name == raw, orElse: () => ThemeMode.system);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, value.name);
  }

  Future<bool> budgetWarningsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_budgetWarningsEnabledKey) ?? true;
  }

  Future<void> setBudgetWarningsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_budgetWarningsEnabledKey, value);
  }

  Future<bool> weeklySummaryEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_weeklySummaryEnabledKey) ?? true;
  }

  Future<void> setWeeklySummaryEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_weeklySummaryEnabledKey, value);
  }
}
```

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/data/local_prefs_test.dart && flutter analyze
git add lib/data/local_prefs.dart test/data/local_prefs_test.dart
git commit -m "feat: add theme mode and notification-toggle persistence to LocalPrefs"
```

---

### Task 2: AccountLinkService — add memberSince

**Files:**
- Modify: `app/lib/data/account_link_service.dart`
- Modify: `app/lib/data/supabase_account_link_service.dart`
- Modify: `app/lib/data/fakes.dart`
- Test: `app/test/data/fakes_test.dart` (extend existing file)

**Interfaces:**
- Produces: `AccountLinkService` gains `DateTime? get memberSince`.

**Before writing any code**: verify the exact `User.createdAt` field type against the installed `gotrue` package source (same approach the account-linking plan's Task 3 used — find it via `app/.dart_tool/package_config.json`) — it may be a `String` (ISO8601) needing `DateTime.parse`, not a `DateTime` directly. Don't guess; read the real source.

- [ ] **Step 1: Write the failing test**

```dart
// Add to app/test/data/fakes_test.dart

test('FakeAccountLinkService.memberSince defaults to null and is settable', () async {
  final service = FakeAccountLinkService();
  expect(service.memberSince, isNull);

  final now = DateTime.now();
  final withMemberSince = FakeAccountLinkService(memberSince: now);
  expect(withMemberSince.memberSince, now);
});
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/data/fakes_test.dart
```

- [ ] **Step 3: Implement**

`app/lib/data/account_link_service.dart` — add to the abstract class:

```dart
DateTime? get memberSince;
```

`app/lib/data/supabase_account_link_service.dart` — add (adjust the exact field access based on your Step-0 verification):

```dart
@override
DateTime? get memberSince {
  final raw = _client.auth.currentUser?.createdAt;
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}
```

`app/lib/data/fakes.dart` — add a constructor parameter and field to `FakeAccountLinkService`:

```dart
class FakeAccountLinkService implements AccountLinkService {
  FakeAccountLinkService({this._isAnonymous = true, this.linkedEmail, this.memberSince});
  bool _isAnonymous;
  @override
  String? linkedEmail;
  @override
  DateTime? memberSince;
  // ...rest unchanged...
}
```

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/data/fakes_test.dart && flutter analyze
git add lib/data/account_link_service.dart lib/data/supabase_account_link_service.dart lib/data/fakes.dart test/data/fakes_test.dart
git commit -m "feat: add memberSince to AccountLinkService"
```

---

### Task 3: ProfileScreen

**Files:**
- Create: `app/lib/screens/profile_screen.dart`
- Test: `app/test/screens/profile_screen_test.dart`

**Interfaces:**
- Produces: `ProfileScreen({required AccountLinkService accountLinkService, required double totalEverTracked, required int categoryCount, required int activeNavIndex, required List<StubNavItem> navItems, required ValueChanged<int> onNavTap, required VoidCallback onScanTap, required VoidCallback onOpenSettings})`. Takes `onOpenSettings` rather than pushing `SettingsScreen` itself — matches this project's established pattern where screens never know about `Navigator` directly, only `RootShell` does.
- Consumes: `AccountLinkService`/`StubAccountLinkPanel` (existing), `StubBottomNav`/`StubCard`/`formatCurrency` (existing).

This must be a `StatefulWidget` (not `StatelessWidget`) because after `StubAccountLinkPanel` successfully links an email, the screen needs to re-read `accountLinkService.isAnonymous`/`linkedEmail` (both live getters) and show the "Linked" state without waiting for a full `RootShell` reload — a bare `setState(() {})` in the panel's `onLinked` callback is enough, since the getters read fresh values each build.

- [ ] **Step 1: Write the failing test**

```dart
// app/test/screens/profile_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/screens/profile_screen.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';
import 'package:stub/widgets/stub_icon.dart';

const _navItems = [
  StubNavItem(icon: StubIcons.home, label: 'Home'),
  StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
  StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
];

void main() {
  testWidgets('ProfileScreen shows anonymous status, stats, and the account-link panel', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(
      accountLinkService: FakeAccountLinkService(),
      totalEverTracked: 1842.30,
      categoryCount: 4,
      activeNavIndex: 2,
      navItems: _navItems,
      onNavTap: (_) {},
      onScanTap: () {},
      onOpenSettings: () {},
    )));

    expect(find.textContaining('Anonymous'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget); // StubAccountLinkPanel's Email row
    expect(find.textContaining('4'), findsWidgets); // category count shown somewhere
  });

  testWidgets('ProfileScreen shows linked status and hides the link panel when not anonymous', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(
      accountLinkService: FakeAccountLinkService(isAnonymous: false, linkedEmail: 'me@example.com'),
      totalEverTracked: 1842.30,
      categoryCount: 4,
      activeNavIndex: 2,
      navItems: _navItems,
      onNavTap: (_) {},
      onScanTap: () {},
      onOpenSettings: () {},
    )));

    expect(find.textContaining('me@example.com'), findsOneWidget);
    expect(find.text('Email'), findsNothing); // panel not shown when already linked
  });

  testWidgets('Tapping the Settings row calls onOpenSettings', (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(
      accountLinkService: FakeAccountLinkService(),
      totalEverTracked: 0,
      categoryCount: 0,
      activeNavIndex: 2,
      navItems: _navItems,
      onNavTap: (_) {},
      onScanTap: () {},
      onOpenSettings: () => opened = true,
    )));

    await tester.tap(find.text('Settings'));
    expect(opened, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/screens/profile_screen_test.dart
```

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import '../data/account_link_service.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/currency.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_account_link_panel.dart';
import '../widgets/stub_pressable.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.accountLinkService,
    required this.totalEverTracked,
    required this.categoryCount,
    required this.activeNavIndex,
    required this.navItems,
    required this.onNavTap,
    required this.onScanTap,
    required this.onOpenSettings,
  });

  final AccountLinkService accountLinkService;
  final double totalEverTracked;
  final int categoryCount;
  final int activeNavIndex;
  final List<StubNavItem> navItems;
  final ValueChanged<int> onNavTap;
  final VoidCallback onScanTap;
  final VoidCallback onOpenSettings;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _memberSinceLabel() {
    final date = widget.accountLinkService.memberSince;
    if (date == null) return '—';
    return '${_months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final service = widget.accountLinkService;

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile', style: StubText.domine(fontSize: 18, color: ink)),
                    const SizedBox(height: 18),
                    StubCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.isAnonymous ? 'Anonymous — not backed up' : 'Linked via ${service.linkedEmail}',
                            style: StubText.archivo(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
                          ),
                          const SizedBox(height: 4),
                          Text('Member since ${_memberSinceLabel()}', style: StubText.archivo(fontSize: 12, color: ink50)),
                          if (service.isAnonymous) ...[
                            const SizedBox(height: 16),
                            StubAccountLinkPanel(
                              accountLinkService: service,
                              onLinked: () => setState(() {}),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    StubCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Stat(label: 'Tracked', value: formatCurrency(widget.totalEverTracked)),
                          _Stat(label: 'Categories', value: '${widget.categoryCount}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    StubPressable(
                      onTap: widget.onOpenSettings,
                      child: StubCard(
                        child: Row(
                          children: [
                            StubIcon(StubIcons.pencil, size: 18, color: ink),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Settings', style: StubText.archivo(fontSize: 15, fontWeight: FontWeight.w600, color: ink))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            StubBottomNav(items: widget.navItems, activeIndex: widget.activeNavIndex, onTap: widget.onNavTap, onScanTap: widget.onScanTap),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink.withValues(alpha: 0.5))),
        const SizedBox(height: 4),
        Text(value, style: StubText.unbounded(fontSize: 16, color: ink)),
      ],
    );
  }
}
```

`StubIcons.pencil` is a placeholder for the Settings row's icon — there's no dedicated "gear/settings" icon in `StubIcons` yet. If you want a proper gear icon, fetch the real Tabler `settings` icon path data the same way the account-linking plan's Task 4 sourced `mail`/`brand-apple`/etc. (from `https://raw.githubusercontent.com/tabler/tabler-icons/main/icons/outline/settings.svg`) and add a `StubIcons.settings` entry — this is a nice-to-have, not required; using `pencil` as a stand-in is acceptable if you want to keep this task's scope tight, but note your choice in the report.

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/screens/profile_screen_test.dart && flutter analyze
git add lib/screens/profile_screen.dart test/screens/profile_screen_test.dart
git commit -m "feat: add ProfileScreen"
```

---

### Task 4: SettingsScreen — shell, theme picker, notification toggles

**Files:**
- Create: `app/lib/screens/settings_screen.dart`
- Test: `app/test/screens/settings_screen_test.dart`

**Interfaces:**
- Produces: `SettingsScreen({required LocalPrefs localPrefs, required ValueNotifier<ThemeMode> themeModeNotifier, required VoidCallback onClose, required VoidCallback onExportData, required VoidCallback onDeleteAllData})`. `onExportData`/`onDeleteAllData` are wired in Tasks 5/6 — this task builds the screen shell with those as no-op-accepting callback slots so the file compiles and is testable independently.
- Consumes: `LocalPrefs` (Task 1), `StubChip` (existing, for the theme picker — same 3-way-selector pattern as `StubPeriodPicker`).

- [ ] **Step 1: Write the failing test**

```dart
// app/test/screens/settings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stub/data/local_prefs.dart';
import 'package:stub/screens/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SettingsScreen shows the theme picker and notification toggles, and persists changes', (tester) async {
    final prefs = LocalPrefs();
    final notifier = ValueNotifier<ThemeMode>(ThemeMode.system);

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(
      localPrefs: prefs,
      themeModeNotifier: notifier,
      onClose: () {},
      onExportData: () {},
      onDeleteAllData: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(notifier.value, ThemeMode.dark);
    expect(await prefs.themeMode(), ThemeMode.dark);

    expect(find.text('Budget limit warnings'), findsOneWidget);
    expect(find.textContaining('not yet'), findsWidgets); // the inert-notifications disclaimer
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/screens/settings_screen_test.dart
```

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import '../data/local_prefs.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_chip.dart';
import '../widgets/stub_icon.dart';

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
                "Not yet wired up — these don't do anything today.",
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
                onPressed: widget.onDeleteAllData,
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
```

Verify `StubColors.dangerLight`/`dangerDark`/`goodLight`/`goodDark` exact names against `app/lib/theme/colors.dart` before using them — this project's other screens (e.g. `edit_entry_screen.dart`, `stub_account_link_panel.dart`) already reference danger; match that exact pattern rather than guessing.

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/screens/settings_screen_test.dart && flutter analyze
git add lib/screens/settings_screen.dart test/screens/settings_screen_test.dart
git commit -m "feat: add SettingsScreen shell with theme picker and notification toggles"
```

---

### Task 5: CSV export

**Files:**
- Create: `app/lib/util/csv_export.dart`
- Test: `app/test/util/csv_export_test.dart`
- Modify: `app/lib/screens/settings_screen.dart` (wire `onExportData`'s actual caller — see Step 4)

**Interfaces:**
- Produces: `String buildTransactionsCsv(List<Transaction> transactions)` — pure function, fully unit-testable, no platform dependency.
- Produces: `Future<void> exportTransactionsCsv(List<Transaction> transactions)` — builds the CSV, writes it to a temp file via `path_provider`, shares it via `share_plus`. This part is NOT unit-tested (no automated way to verify the OS share sheet actually received a file) — verified only by manual/scripted smoke test, same pattern as this project's Supabase-backed repositories.

- [ ] **Step 1: Add dependencies**

```bash
cd app
flutter pub add share_plus
flutter pub add path_provider
```

- [ ] **Step 2: Write the failing test** (for the pure function only)

```dart
// app/test/util/csv_export_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/util/csv_export.dart';

void main() {
  test('buildTransactionsCsv produces a header row plus one row per transaction', () {
    final transactions = [
      Transaction(
        id: 't1',
        categoryId: 'c1',
        merchant: 'Corner Market',
        amount: 18.42,
        category: 'Groceries',
        source: TransactionSource.receipt,
        occurredAt: DateTime(2026, 8, 25),
      ),
    ];

    final csv = buildTransactionsCsv(transactions);
    final lines = csv.trim().split('\n');

    expect(lines[0], 'Date,Merchant,Amount,Category,Source');
    expect(lines[1], contains('Corner Market'));
    expect(lines[1], contains('18.42'));
    expect(lines[1], contains('Groceries'));
  });

  test('buildTransactionsCsv escapes a comma in a merchant name', () {
    final transactions = [
      Transaction(
        id: 't1',
        categoryId: 'c1',
        merchant: 'Smith, Jones & Co',
        amount: 10,
        category: 'Groceries',
        source: TransactionSource.manual,
        occurredAt: DateTime(2026, 8, 25),
      ),
    ];

    final csv = buildTransactionsCsv(transactions);
    expect(csv, contains('"Smith, Jones & Co"'));
  });
}
```

- [ ] **Step 3: Run to verify it fails**

```
cd app && flutter test test/util/csv_export_test.dart
```

- [ ] **Step 4: Implement**

```dart
// app/lib/util/csv_export.dart
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _sourceLabel(TransactionSource source) => switch (source) {
      TransactionSource.receipt => 'Receipt',
      TransactionSource.paymentApp => 'Payment app',
      TransactionSource.bankScreenshot => 'Bank screenshot',
      TransactionSource.manual => 'Manual',
    };

/// Pure, fully unit-testable — no platform/file dependency.
String buildTransactionsCsv(List<Transaction> transactions) {
  final buffer = StringBuffer('Date,Merchant,Amount,Category,Source\n');
  for (final t in transactions) {
    final date = '${t.occurredAt.year}-${t.occurredAt.month.toString().padLeft(2, '0')}-${t.occurredAt.day.toString().padLeft(2, '0')}';
    buffer.writeln([
      date,
      _csvField(t.merchant),
      t.amount.toStringAsFixed(2),
      _csvField(t.category),
      _sourceLabel(t.source),
    ].join(','));
  }
  return buffer.toString();
}

/// Writes the CSV to a temp file and hands it to the OS share sheet.
/// Not unit-tested — verify manually per this task's brief.
Future<void> exportTransactionsCsv(List<Transaction> transactions) async {
  final csv = buildTransactionsCsv(transactions);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/stub_transactions.csv');
  await file.writeAsString(csv);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Stub transactions export'));
}
```

Verify the exact `SharePlus`/`ShareParams`/`XFile` API against the installed `share_plus` package version before finalizing (its API has changed across versions — check `share_plus`'s actual installed version's source, don't assume the snippet above is exactly right if the resolved version differs). `cross_file`'s `XFile` may need `flutter pub add cross_file` explicitly if it isn't already re-exported/available transitively — check by running `flutter analyze` after adding the two dependencies above and adjust imports as needed.

- [ ] **Step 5: Wire it into `SettingsScreen`**

This function needs the current transaction list, which `SettingsScreen` doesn't have — per this project's established pattern, the actual repository access happens at `RootShell`, not inside a leaf screen. So `SettingsScreen`'s `onExportData` stays a plain `VoidCallback` (already defined in Task 4) — Task 8 (RootShell wiring) is what actually calls `exportTransactionsCsv(data.transactions)` and passes the result as that callback. No change needed to `settings_screen.dart` itself in this task — just confirm the callback shape from Task 4 (`VoidCallback`, no params) is still what you want; if you'd rather have `RootShell` compute the CSV once and pass a ready `Future<void> Function()` in, that's an equally valid shape — note your choice in the report for Task 8's implementer to match.

- [ ] **Step 6: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/util/csv_export_test.dart && flutter analyze
git add pubspec.yaml pubspec.lock lib/util/csv_export.dart test/util/csv_export_test.dart
git commit -m "feat: add CSV export via the OS share sheet"
```

---

### Task 6: Delete all data

**Files:**
- Modify: `app/lib/screens/settings_screen.dart` (the confirmation dialog lives here; the actual delete loop is wired in Task 8, same split as Task 5's export)

**Interfaces:**
- `SettingsScreen`'s "Delete all data" button opens a confirmation `AlertDialog` before calling `widget.onDeleteAllData` — never delete without an explicit second confirmation, since this is irreversible.

- [ ] **Step 1: Write the failing test**

```dart
// Add to app/test/screens/settings_screen_test.dart

testWidgets('Delete all data requires confirmation before calling onDeleteAllData', (tester) async {
  var deleted = false;
  final prefs = LocalPrefs();
  final notifier = ValueNotifier<ThemeMode>(ThemeMode.system);

  await tester.pumpWidget(MaterialApp(home: SettingsScreen(
    localPrefs: prefs,
    themeModeNotifier: notifier,
    onClose: () {},
    onExportData: () {},
    onDeleteAllData: () => deleted = true,
  )));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Delete all data'));
  await tester.pumpAndSettle();

  // Confirmation dialog shown, callback not yet called.
  expect(find.textContaining('permanently delete'), findsOneWidget);
  expect(deleted, isFalse);

  await tester.tap(find.text('Delete everything'));
  await tester.pumpAndSettle();

  expect(deleted, isTrue);
});
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/screens/settings_screen_test.dart
```

- [ ] **Step 3: Implement**

In `settings_screen.dart`, change the "Delete all data" `OutlinedButton`'s `onPressed` from `widget.onDeleteAllData` directly to a new method:

```dart
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
```

and change the button's `onPressed: widget.onDeleteAllData` to `onPressed: _confirmDeleteAllData`.

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/screens/settings_screen_test.dart && flutter analyze
git add lib/screens/settings_screen.dart test/screens/settings_screen_test.dart
git commit -m "feat: require confirmation before deleting all data"
```

---

### Task 7: Live theme reactivity

**Files:**
- Modify: `app/lib/main.dart`

**Interfaces:**
- `StubApp` gains a required `ValueNotifier<ThemeMode> themeModeNotifier` parameter, threaded through to `_LockGate` and wrapped around `MaterialApp`'s `themeMode` via `ValueListenableBuilder`.
- `main()` reads the persisted theme via `LocalPrefs().themeMode()` before `runApp`, seeding the notifier's initial value.

- [ ] **Step 1: Read `main.dart`'s current structure** — no prescriptive code for this step; read the file first (it's changed shape multiple times across this project's history), don't guess.

- [ ] **Step 2: Write the failing test**

Extend `app/test/widget_test.dart` (or add a focused new test) covering: `StubApp` constructed with a `ValueNotifier<ThemeMode>(ThemeMode.dark)` actually renders with dark theme applied — check via `find.byType(MaterialApp)`'s resolved `themeMode` property, or a simpler smoke check that changing the notifier's value after the widget is built causes a rebuild reflecting the new mode (e.g. pump after `notifier.value = ThemeMode.light` and confirm no exception, plus inspect `tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode` equals the new value).

- [ ] **Step 3: Run to verify it fails**

```
cd app && flutter test
```

- [ ] **Step 4: Implement**

In `main()`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
  await _ensureSession();
  final localPrefs = LocalPrefs();
  final themeModeNotifier = ValueNotifier<ThemeMode>(await localPrefs.themeMode());
  runApp(StubApp(
    categoryRepository: SupabaseCategoryRepository(Supabase.instance.client),
    transactionRepository: SupabaseTransactionRepository(Supabase.instance.client),
    budgetRepository: SupabaseBudgetRepository(Supabase.instance.client),
    accountLinkService: SupabaseAccountLinkService(Supabase.instance.client),
    localPrefs: localPrefs,
    themeModeNotifier: themeModeNotifier,
  ));
}
```

In `StubApp`, add the `themeModeNotifier` field/param, and wrap the `MaterialApp` in a `ValueListenableBuilder`:

```dart
@override
Widget build(BuildContext context) {
  return ValueListenableBuilder<ThemeMode>(
    valueListenable: themeModeNotifier,
    builder: (context, mode, _) => MaterialApp(
      title: 'Stub',
      debugShowCheckedModeBanner: false,
      theme: StubTheme.light(),
      darkTheme: StubTheme.dark(),
      themeMode: mode,
      home: _LockGate(
        categoryRepository: categoryRepository,
        transactionRepository: transactionRepository,
        budgetRepository: budgetRepository,
        accountLinkService: accountLinkService,
        localPrefs: localPrefs,
        themeModeNotifier: themeModeNotifier,
      ),
    ),
  );
}
```

Thread `themeModeNotifier` through `_LockGate` the same way the other 5 dependencies already are (constructor param, field, passed to `RootShell` in Task 8).

- [ ] **Step 5: Run tests, `flutter analyze`, commit**

```
cd app && flutter test && flutter analyze
git add lib/main.dart test/widget_test.dart
git commit -m "feat: make theme mode live-reactive via a ValueNotifier read from LocalPrefs at startup"
```

---

### Task 8: Wire RootShell — real Profile tab, Settings navigation, export, delete-all

**Files:**
- Modify: `app/lib/screens/root_shell.dart` (full Profile-tab wiring)
- Modify: `app/lib/main.dart` (thread `accountLinkService`/`themeModeNotifier` into `RootShell`'s construction inside `_LockGate`)
- Test: `app/test/screens/root_shell_test.dart` (extend existing file)

**Interfaces:**
- `RootShell` gains 2 more required constructor parameters: `AccountLinkService accountLinkService`, `ValueNotifier<ThemeMode> themeModeNotifier` (alongside the existing 3 repositories).
- Consumes: `ProfileScreen` (Task 3), `SettingsScreen` (Task 4/6), `exportTransactionsCsv` (Task 5).

This is the integration task that removes the last of the "Profile falls back to Ledger" behavior and connects every piece built in Tasks 1-7.

- [ ] **Step 1: Write the failing test**

```dart
// Add to app/test/screens/root_shell_test.dart

testWidgets('Profile tab shows the real ProfileScreen, not Ledger content', (tester) async {
  await tester.pumpWidget(MaterialApp(home: RootShell(
    categoryRepository: FakeCategoryRepository(),
    transactionRepository: FakeTransactionRepository(),
    budgetRepository: FakeBudgetRepository(),
    accountLinkService: FakeAccountLinkService(),
    themeModeNotifier: ValueNotifier(ThemeMode.system),
    localPrefs: LocalPrefs(),
  )));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Profile'));
  await tester.pumpAndSettle();

  expect(find.text('Anonymous — not backed up'), findsOneWidget);
  expect(find.text('LEFT TO SPEND'), findsNothing); // no longer falling back to Ledger
});

testWidgets('Tapping Settings from Profile opens SettingsScreen', (tester) async {
  await tester.pumpWidget(MaterialApp(home: RootShell(
    categoryRepository: FakeCategoryRepository(),
    transactionRepository: FakeTransactionRepository(),
    budgetRepository: FakeBudgetRepository(),
    accountLinkService: FakeAccountLinkService(),
    themeModeNotifier: ValueNotifier(ThemeMode.system),
    localPrefs: LocalPrefs(),
  )));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Profile'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();

  expect(find.text('THEME'), findsOneWidget);
});
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/screens/root_shell_test.dart
```

- [ ] **Step 3: Implement**

Add `accountLinkService`/`themeModeNotifier` to `RootShell`'s constructor and fields, matching the existing 3 repositories' pattern exactly.

Replace the `else` branch's forced-to-Ledger behavior for `_tabIndex == 2` with a real third branch:

```dart
if (_tabIndex == 1) {
  // ...existing Budgets branch, unchanged...
} else if (_tabIndex == 2) {
  final totalEverTracked = data.transactions.fold<double>(0, (sum, t) => sum + t.amount);
  content = ProfileScreen(
    accountLinkService: widget.accountLinkService,
    totalEverTracked: totalEverTracked,
    categoryCount: data.categories.length,
    activeNavIndex: _tabIndex,
    navItems: _navItems,
    onNavTap: (i) => setState(() => _tabIndex = i),
    onScanTap: _openScan,
    onOpenSettings: () => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        localPrefs: widget.localPrefs,
        themeModeNotifier: widget.themeModeNotifier,
        onClose: () => Navigator.of(context).pop(),
        onExportData: () => exportTransactionsCsv(data.transactions),
        onDeleteAllData: () => _guardedWrite(() async {
          for (final t in data.transactions) {
            await widget.transactionRepository.delete(t.id);
          }
          for (final c in data.categories) {
            await widget.categoryRepository.delete(c.id);
          }
        }, onSuccess: () => Navigator.of(context).pop()),
      ),
    )),
  );
} else {
  // ...existing Ledger branch, now only reached for _tabIndex == 0...
}
```

`RootShell` needs a `LocalPrefs` too (for `SettingsScreen`'s `localPrefs` param) — add it as a 3rd new required constructor parameter alongside `accountLinkService`/`themeModeNotifier`, threaded from `main.dart`/`_LockGate` the same way.

Remove the now-obsolete comment about tab 2 falling back to Ledger, and the `activeNavIndex: _tabIndex == 2 ? 0 : _tabIndex` special-casing in the Ledger branch (that was specifically to keep the nav highlight honest while tab 2 showed Ledger content — no longer needed once tab 2 shows its own real screen; the Ledger branch's `activeNavIndex` can just be `_tabIndex` directly, since it's now only ever reached when `_tabIndex == 0`).

Update `main.dart`'s `_LockGate`/`_LockGateState` to thread `localPrefs`/`accountLinkService`/`themeModeNotifier` into `RootShell`'s construction (it already holds all three from Task 7 and the account-linking plan — just add them to the `RootShell(...)` call).

- [ ] **Step 4: Run the full suite, fix any other affected call site**

```
cd app && flutter test
```

Fix any remaining compile errors from the constructor signature change — expected, mechanical work.

- [ ] **Step 5: `flutter analyze`, manual verification, commit**

```
cd app && flutter analyze
```

Manually trace (code inspection, since no device is available in this environment): does tapping Profile show real stats? Does Settings' theme picker actually change `MaterialApp`'s live theme? Does Export produce a real file via `share_plus` (this specific piece needs a real device to verify — note in your report that it wasn't run live, consistent with this project's established pattern for anything needing OS-level integration)?

```
git add lib/screens/root_shell.dart lib/main.dart test/screens/root_shell_test.dart
git commit -m "feat: wire RootShell to the real ProfileScreen and SettingsScreen"
```

---

### Task 9: CLAUDE.md documentation update

**Files:**
- Modify: `CLAUDE.md` (repo root)

**Interfaces:** none (docs only).

- [ ] **Step 1: Update the file map**

Add rows for every new file: `lib/screens/profile_screen.dart`, `lib/screens/settings_screen.dart`, `lib/util/csv_export.dart`, plus their test files. Update `LocalPrefs`'s row (theme + notification persistence added), `AccountLinkService`'s row (`memberSince` added).

- [ ] **Step 2: Update the Status paragraph**

Reflect that the Profile tab now shows a real screen (not falling back to Ledger), the screen count, and the real final test count (run `flutter test` yourself — don't guess).

- [ ] **Step 3: Update the Component inventory**

Add `ProfileScreen`, `SettingsScreen`. Note the new `SwitchListTile.adaptive` usage for notification toggles as this project's first toggle-style control, if nothing else in the component inventory already covers it.

- [ ] **Step 4: Update Open Items**

Verify each against current code before writing (this project has twice caught hallucinated CLAUDE.md claims — read the real files):
- Notification toggles are UI-only, not wired to any real notification system.
- "Delete account" is a disabled row — real account deletion needs a Supabase Edge Function, not built.
- CSV export via `share_plus` has not been verified on a real device (no device available during development).
- If SMTP still isn't configured (check `app/supabase/config.toml`'s `[auth.email.smtp]` block before writing this — it may have been resolved by the time you do this task), keep or update that existing Open Item accordingly rather than assuming its state.

- [ ] **Step 5: Commit**

```
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for Profile & Settings"
```
