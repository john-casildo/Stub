import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:stub/data/fakes.dart';
import 'package:stub/data/local_prefs.dart';
import 'package:stub/main.dart';

/// A [SharedPreferencesStorePlatform] whose reads/writes always throw, used
/// to force a real failure through [LocalPrefs] (which wraps the real
/// `SharedPreferences` API) without needing to turn `LocalPrefs` into an
/// interface with a fake just for this one test.
class _ThrowingSharedPreferencesStore extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() => throw Exception('local prefs unavailable');
  @override
  Future<Map<String, Object>> getAll() =>
      throw Exception('local prefs unavailable');
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

  testWidgets('App boots locked and unlocks into the ledger', (tester) async {
    // Backup prompt already seen — this test only covers the plain
    // lock/unlock transition, not the one-time prompt.
    SharedPreferences.setMockInitialValues({'has_seen_backup_prompt': true});

    await tester.pumpWidget(StubApp(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      localPrefs: LocalPrefs(),
      themeModeNotifier: ValueNotifier<ThemeMode>(ThemeMode.system),
      currencyNotifier: ValueNotifier<String>("USD"),
      textRecognitionService: FakeTextRecognitionService(),
      deviceAuthService: FakeDeviceAuthService(),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      notificationService: FakeNotificationService(),
    ));
    await tester.pump();

    expect(find.text('Stub is locked'), findsOneWidget);

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('RECENT'), findsOneWidget);
  });

  testWidgets('Turning lockEnabledNotifier off skips the lock screen entirely', (tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_backup_prompt': true});
    final lockEnabledNotifier = ValueNotifier<bool>(true);

    await tester.pumpWidget(StubApp(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      localPrefs: LocalPrefs(),
      themeModeNotifier: ValueNotifier<ThemeMode>(ThemeMode.system),
      currencyNotifier: ValueNotifier<String>("USD"),
      textRecognitionService: FakeTextRecognitionService(),
      deviceAuthService: FakeDeviceAuthService(),
      lockEnabledNotifier: lockEnabledNotifier,
      notificationService: FakeNotificationService(),
    ));
    await tester.pump();

    expect(find.text('Stub is locked'), findsOneWidget);

    lockEnabledNotifier.value = false;
    await tester.pumpAndSettle();

    expect(find.text('Stub is locked'), findsNothing);
    expect(find.text('RECENT'), findsOneWidget);
  });

  testWidgets('First unlock shows the backup prompt before the ledger; skipping continues past it', (tester) async {
    await tester.pumpWidget(StubApp(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      localPrefs: LocalPrefs(),
      themeModeNotifier: ValueNotifier<ThemeMode>(ThemeMode.system),
      currencyNotifier: ValueNotifier<String>("USD"),
      textRecognitionService: FakeTextRecognitionService(),
      deviceAuthService: FakeDeviceAuthService(),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      notificationService: FakeNotificationService(),
    ));
    await tester.pump();

    await tester.tap(find.text('Unlock'));
    await tester.pump();

    expect(find.text('Back up your data'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('RECENT'), findsOneWidget);
  });

  testWidgets(
    'A broken local-prefs read on unlock does not strand the app on a blank screen',
    (tester) async {
      // Force a real failure through LocalPrefs's underlying
      // SharedPreferences calls (rather than stubbing LocalPrefs itself,
      // which isn't an interface) to prove _LockGate's guard falls
      // through to RootShell instead of hanging on SizedBox.shrink().
      SharedPreferencesStorePlatform.instance = _ThrowingSharedPreferencesStore();

      await tester.pumpWidget(StubApp(
        categoryRepository: FakeCategoryRepository(),
        transactionRepository: FakeTransactionRepository(),
        budgetRepository: FakeBudgetRepository(),
        accountLinkService: FakeAccountLinkService(),
        localPrefs: LocalPrefs(),
        themeModeNotifier: ValueNotifier<ThemeMode>(ThemeMode.system),
        currencyNotifier: ValueNotifier<String>("USD"),
        textRecognitionService: FakeTextRecognitionService(),
        deviceAuthService: FakeDeviceAuthService(),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      notificationService: FakeNotificationService(),
      ));
      await tester.pump();

      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      // Falls straight through to RootShell — no blank screen, no
      // backup-prompt (its "already seen" flag couldn't be read either).
      expect(find.text('RECENT'), findsOneWidget);
      expect(find.text('Back up your data'), findsNothing);
    },
  );

  testWidgets('themeModeNotifier drives MaterialApp.themeMode live', (tester) async {
    SharedPreferences.setMockInitialValues({'has_seen_backup_prompt': true});
    final notifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

    await tester.pumpWidget(StubApp(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      localPrefs: LocalPrefs(),
      themeModeNotifier: notifier,
      currencyNotifier: ValueNotifier<String>("USD"),
      textRecognitionService: FakeTextRecognitionService(),
      deviceAuthService: FakeDeviceAuthService(),
      lockEnabledNotifier: ValueNotifier<bool>(true),
      notificationService: FakeNotificationService(),
    ));

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    notifier.value = ThemeMode.light;
    await tester.pump();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });
}
