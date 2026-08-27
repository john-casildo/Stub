import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stub/data/local_prefs.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('hasSeenBackupPrompt defaults to false, then persists true after being set', () async {
    final prefs = LocalPrefs();
    expect(await prefs.hasSeenBackupPrompt(), isFalse);

    await prefs.setHasSeenBackupPrompt(true);
    expect(await prefs.hasSeenBackupPrompt(), isTrue);
  });

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
}
