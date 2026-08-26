import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/lock_screen.dart';

void main() {
  testWidgets('LockScreen shows the lock copy and unlocks on tap', (tester) async {
    var unlocked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(onUnlock: () => unlocked = true, onUsePasscode: () {}),
      ),
    );
    expect(find.text('Stub is locked'), findsOneWidget);
    await tester.tap(find.text('Unlock with Face ID'));
    expect(unlocked, isTrue);
  });
}
