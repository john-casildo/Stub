import 'package:shared_preferences/shared_preferences.dart';

/// Local, per-device UI preferences — never financial data, never synced
/// through Supabase. See DESIGN spec: theme + the one-time backup-prompt
/// flag both belong here.
class LocalPrefs {
  static const _hasSeenBackupPromptKey = 'has_seen_backup_prompt';

  Future<bool> hasSeenBackupPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenBackupPromptKey) ?? false;
  }

  Future<void> setHasSeenBackupPrompt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenBackupPromptKey, value);
  }
}
