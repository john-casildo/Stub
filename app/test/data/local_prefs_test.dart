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

  test('currencyCode defaults to USD, then persists the set value', () async {
    final prefs = LocalPrefs();
    expect(await prefs.currencyCode(), 'USD');

    await prefs.setCurrencyCode('CRC');
    expect(await prefs.currencyCode(), 'CRC');
  });

  test('localeCode defaults to null (system), then persists the set value', () async {
    final prefs = LocalPrefs();
    expect(await prefs.localeCode(), isNull);

    await prefs.setLocaleCode('es');
    expect(await prefs.localeCode(), 'es');

    await prefs.setLocaleCode(null);
    expect(await prefs.localeCode(), isNull);
  });

  test('lockEnabled defaults to true, then persists the set value', () async {
    final prefs = LocalPrefs();
    expect(await prefs.lockEnabled(), isTrue);

    await prefs.setLockEnabled(false);
    expect(await prefs.lockEnabled(), isFalse);
  });

  test('notifiedThresholdFor defaults to null, then persists per category+period, independently', () async {
    final prefs = LocalPrefs();
    final periodA = DateTime(2026, 9, 1);
    final periodB = DateTime(2026, 10, 1);

    expect(await prefs.notifiedThresholdFor('c1', periodA), isNull);

    await prefs.setNotifiedThresholdFor('c1', periodA, 0.9);
    expect(await prefs.notifiedThresholdFor('c1', periodA), 0.9);
    // A different category, and the same category in a different period
    // (e.g. after the budget rolled over), are untouched.
    expect(await prefs.notifiedThresholdFor('c2', periodA), isNull);
    expect(await prefs.notifiedThresholdFor('c1', periodB), isNull);

    await prefs.setNotifiedThresholdFor('c1', periodA, 1.0);
    expect(await prefs.notifiedThresholdFor('c1', periodA), 1.0);
  });
}
