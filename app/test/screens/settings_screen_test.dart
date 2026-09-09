import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/data/local_prefs.dart';
import 'package:stub/screens/settings_screen.dart';
import 'package:stub/widgets/stub_loading_indicator.dart';

/// A [SharedPreferencesStorePlatform] whose reads/writes always throw, used
/// to force a real failure through [LocalPrefs] — same pattern as
/// `_ThrowingSharedPreferencesStore` in `test/widget_test.dart`, built for
/// the identical bug in `_LockGate`.
class _ThrowingSharedPreferencesStore extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() => throw Exception('local prefs unavailable');
  @override
  Future<Map<String, Object>> getAll() => throw Exception('local prefs unavailable');
  @override
  Future<bool> remove(String key) => throw Exception('local prefs unavailable');
  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      throw Exception('local prefs unavailable');
}

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
      currencyNotifier: ValueNotifier<String>('USD'),
      notificationService: FakeNotificationService(),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      lockSupported: true,
      onWeeklySummaryToggled: (_) async {},
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
    expect(find.text('Weekly summary'), findsOneWidget);
  });

  testWidgets('Shows the Face ID/passcode toggle when the device supports it, and persists changes', (tester) async {
    final prefs = LocalPrefs();
    final lockEnabledNotifier = ValueNotifier<bool>(true);

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(
      localPrefs: prefs,
      themeModeNotifier: ValueNotifier<ThemeMode>(ThemeMode.system),
      currencyNotifier: ValueNotifier<String>('USD'),
      notificationService: FakeNotificationService(),
      lockEnabledNotifier: lockEnabledNotifier,
      lockSupported: true,
      onWeeklySummaryToggled: (_) async {},
      onClose: () {},
      onExportData: () {},
      onDeleteAllData: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Require Face ID / Passcode'), findsOneWidget);

    await tester.tap(find.text('Require Face ID / Passcode'));
    await tester.pump();

    expect(lockEnabledNotifier.value, isFalse);
    expect(await prefs.lockEnabled(), isFalse);
  });

  testWidgets('Hides the Face ID/passcode toggle when the device has nothing enrolled', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(
      localPrefs: LocalPrefs(),
      themeModeNotifier: ValueNotifier<ThemeMode>(ThemeMode.system),
      currencyNotifier: ValueNotifier<String>('USD'),
      notificationService: FakeNotificationService(),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      lockSupported: false,
      onWeeklySummaryToggled: (_) async {},
      onClose: () {},
      onExportData: () {},
      onDeleteAllData: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Require Face ID / Passcode'), findsNothing);
  });

  testWidgets('Turning on Budget limit warnings requests notification permission', (tester) async {
    final notifications = FakeNotificationService();

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(
      localPrefs: LocalPrefs(),
      themeModeNotifier: ValueNotifier<ThemeMode>(ThemeMode.system),
      currencyNotifier: ValueNotifier<String>('USD'),
      notificationService: notifications,
      lockEnabledNotifier: ValueNotifier<bool>(true),
      lockSupported: true,
      onWeeklySummaryToggled: (_) async {},
      onClose: () {},
      onExportData: () {},
      onDeleteAllData: () {},
    )));
    await tester.pumpAndSettle();

    // Off then on, to make sure the permission request fires on the
    // enabling edge, not unconditionally on every toggle change.
    await tester.tap(find.text('Budget limit warnings'));
    await tester.pump();
    expect(notifications.permissionRequested, isFalse);

    await tester.tap(find.text('Budget limit warnings'));
    await tester.pump();
    expect(notifications.permissionRequested, isTrue);
  });

  testWidgets('Shows a message when notification permission is denied', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(
      localPrefs: LocalPrefs(),
      themeModeNotifier: ValueNotifier<ThemeMode>(ThemeMode.system),
      currencyNotifier: ValueNotifier<String>('USD'),
      notificationService: FakeNotificationService(permissionGranted: false),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      lockSupported: true,
      onWeeklySummaryToggled: (_) async {},
      onClose: () {},
      onExportData: () {},
      onDeleteAllData: () {},
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Budget limit warnings'));
    await tester.pump();
    await tester.tap(find.text('Budget limit warnings'));
    await tester.pump();

    expect(find.textContaining('blocked'), findsOneWidget);
  });

  testWidgets('SettingsScreen shows the currency picker and persists changes', (tester) async {
    final prefs = LocalPrefs();
    final currencyNotifier = ValueNotifier<String>('USD');

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(
      localPrefs: prefs,
      themeModeNotifier: ValueNotifier<ThemeMode>(ThemeMode.system),
      currencyNotifier: currencyNotifier,
      notificationService: FakeNotificationService(),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      lockSupported: true,
      onWeeklySummaryToggled: (_) async {},
      onClose: () {},
      onExportData: () {},
      onDeleteAllData: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('USD'), findsOneWidget);

    // Not just USD/CRC — the picker offers a broad set of world currencies.
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    expect(find.text('EUR').last, findsOneWidget);
    await tester.tap(find.text('EUR').last);
    await tester.pumpAndSettle();

    expect(currencyNotifier.value, 'EUR');
    expect(await prefs.currencyCode(), 'EUR');
  });

  testWidgets('Delete all data requires confirmation before calling onDeleteAllData', (tester) async {
    var deleted = false;
    final prefs = LocalPrefs();
    final notifier = ValueNotifier<ThemeMode>(ThemeMode.system);

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(
      localPrefs: prefs,
      themeModeNotifier: notifier,
      currencyNotifier: ValueNotifier<String>('USD'),
      notificationService: FakeNotificationService(),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      lockSupported: true,
      onWeeklySummaryToggled: (_) async {},
      onClose: () {},
      onExportData: () {},
      onDeleteAllData: () => deleted = true,
    )));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete all data'));
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

  testWidgets('A broken local-prefs load still renders the screen with a working close button, not a stuck spinner', (tester) async {
    // `setUp` above resets `SharedPreferences`'s mock store before every
    // test, so no explicit teardown is needed to undo this.
    SharedPreferencesStorePlatform.instance = _ThrowingSharedPreferencesStore();

    var closed = false;
    final prefs = LocalPrefs();
    final notifier = ValueNotifier<ThemeMode>(ThemeMode.system);

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(
      localPrefs: prefs,
      themeModeNotifier: notifier,
      currencyNotifier: ValueNotifier<String>('USD'),
      notificationService: FakeNotificationService(),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      lockSupported: true,
      onWeeklySummaryToggled: (_) async {},
      onClose: () => closed = true,
      onExportData: () {},
      onDeleteAllData: () {},
    )));

    // The app bar (with its working close button) is up immediately,
    // regardless of how `_load()`'s failing read resolves — there's no
    // frame where the user is stuck looking at a bare, escape-hatch-free
    // screen.
    await tester.pump();
    expect(find.byType(AppBar), findsOneWidget);

    await tester.pumpAndSettle();

    // Falls back to defaults and renders the real screen instead of hanging
    // on the loading spinner forever.
    expect(find.byType(StubLoadingIndicator), findsNothing);
    expect(find.text('THEME'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);

    // The close button is reachable and still works once the screen has
    // rendered.
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });
}
