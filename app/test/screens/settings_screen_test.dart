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
