import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/screens/lock_screen.dart';

void main() {
  testWidgets('LockScreen shows the lock copy and unlocks on successful auth', (tester) async {
    var unlocked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          deviceAuthService: FakeDeviceAuthService(),
          onUnlock: () => unlocked = true,
        ),
      ),
    );
    expect(find.text('Stub is locked'), findsOneWidget);

    await tester.tap(find.text('Unlock'));
    await tester.pump();

    expect(unlocked, isTrue);
  });

  testWidgets('LockScreen stays locked and shows an error when auth fails', (tester) async {
    var unlocked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(
          deviceAuthService: FakeDeviceAuthService(succeeds: false),
          onUnlock: () => unlocked = true,
        ),
      ),
    );

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(unlocked, isFalse);
    expect(find.text('Stub is locked'), findsOneWidget);
    expect(find.textContaining("Couldn't verify"), findsOneWidget);
  });
}
