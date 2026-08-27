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
}
