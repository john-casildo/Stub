import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:stub/data/local_prefs.dart';
import 'package:stub/screens/settings_screen.dart';

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
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('THEME'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);

    // The close button is reachable and still works once the screen has
    // rendered.
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });
}
