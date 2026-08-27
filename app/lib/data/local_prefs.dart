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
}
