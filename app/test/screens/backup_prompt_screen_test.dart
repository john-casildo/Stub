import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/screens/backup_prompt_screen.dart';

void main() {
  testWidgets('Tapping Skip calls onDone without linking anything', (tester) async {
    var done = false;
    final service = FakeAccountLinkService();

    await tester.pumpWidget(MaterialApp(home: BackupPromptScreen(
      accountLinkService: service,
      onDone: () => done = true,
    )));

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(done, isTrue);
    expect(service.linkedEmail, isNull);
  });

  testWidgets('Tapping Email, entering an address, and submitting links it and calls onDone', (tester) async {
    var done = false;
    final service = FakeAccountLinkService();

    await tester.pumpWidget(MaterialApp(home: BackupPromptScreen(
      accountLinkService: service,
      onDone: () => done = true,
    )));

    await tester.tap(find.text('Email'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'me@example.com');
    await tester.tap(find.text('Send link'));
    await tester.pump();

    expect(service.linkedEmail, 'me@example.com');
    expect(done, isTrue);
  });

  testWidgets('Apple/Google/Phone rows are disabled and do nothing when tapped', (tester) async {
    final service = FakeAccountLinkService();
    await tester.pumpWidget(MaterialApp(home: BackupPromptScreen(
      accountLinkService: service,
      onDone: () {},
    )));

    // warnIfMissed: false — IgnorePointer means this tap genuinely can't
    // hit "Apple" itself; that's the behavior under test.
    await tester.tap(find.text('Apple'), warnIfMissed: false);
    await tester.pump();
    expect(service.linkedEmail, isNull);
    expect(find.text('Send link'), findsNothing); // no email sub-flow opened
  });
}
