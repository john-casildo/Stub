import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local, per-device UI preferences — never financial data, never synced
/// through Supabase. See DESIGN spec: theme + the one-time backup-prompt
/// flag both belong here.
class LocalPrefs {
  static const _hasSeenBackupPromptKey = 'has_seen_backup_prompt';
  static const _themeModeKey = 'theme_mode';
  static const _budgetWarningsEnabledKey = 'budget_warnings_enabled';
  static const _weeklySummaryEnabledKey = 'weekly_summary_enabled';
  static const _currencyCodeKey = 'currency_code';
  static const _localeCodeKey = 'locale_code';
  static const _notifiedThresholdsKey = 'budget_notified_thresholds';
  static const _lockEnabledKey = 'lock_enabled';

  Future<bool> hasSeenBackupPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenBackupPromptKey) ?? false;
  }

  Future<void> setHasSeenBackupPrompt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenBackupPromptKey, value);
  }

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

  Future<String> currencyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyCodeKey) ?? 'USD';
  }

  Future<void> setCurrencyCode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyCodeKey, value);
  }

  /// Null means "follow the system locale" — the default until the user
  /// picks an explicit language in Settings.
  Future<String?> localeCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localeCodeKey);
  }

  Future<void> setLocaleCode(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_localeCodeKey);
    } else {
      await prefs.setString(_localeCodeKey, value);
    }
  }

  /// The highest budget-notification threshold (see
  /// `util/budget_thresholds.dart`) already fired for [categoryId] within
  /// the budget period starting [periodStart] — null if none yet. Keyed
  /// by period start so a new period (the budget rolling over) starts
  /// fresh automatically, without needing an explicit reset anywhere.
  Future<double?> notifiedThresholdFor(String categoryId, DateTime periodStart) async {
    final map = await _notifiedThresholds();
    final value = map['$categoryId:${periodStart.toIso8601String()}'];
    return value == null ? null : (value as num).toDouble();
  }

  Future<void> setNotifiedThresholdFor(String categoryId, DateTime periodStart, double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await _notifiedThresholds();
    map['$categoryId:${periodStart.toIso8601String()}'] = threshold;
    await prefs.setString(_notifiedThresholdsKey, jsonEncode(map));
  }

  /// Whether the device's biometric/passcode lock gates the app at all —
  /// defaults `true` so nothing changes for existing users unless they
  /// explicitly turn it off in Settings. Meaningless on a device with no
  /// biometric/passcode enrolled at all (`DeviceAuthService.isSupported()`
  /// false) — there's nothing to gate on either way there.
  Future<bool> lockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockEnabledKey) ?? true;
  }

  Future<void> setLockEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockEnabledKey, value);
  }

  Future<Map<String, dynamic>> _notifiedThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notifiedThresholdsKey);
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
