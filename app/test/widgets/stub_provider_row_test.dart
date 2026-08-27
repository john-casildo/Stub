import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_icon.dart';
import 'package:stub/widgets/stub_provider_row.dart';

void main() {
  testWidgets('StubProviderRow reports taps when enabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Center(child: StubProviderRow(
      icon: StubIcons.mail,
      label: 'Email',
      enabled: true,
      onTap: () => tapped = true,
    ))));

    await tester.tap(find.text('Email'));
    expect(tapped, isTrue);
    expect(find.text('Coming soon'), findsNothing);
  });

  testWidgets('StubProviderRow shows a Coming soon tag and ignores taps when disabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Center(child: StubProviderRow(
      icon: StubIcons.brandApple,
      label: 'Apple',
      enabled: false,
      onTap: () => tapped = true,
    ))));

    expect(find.text('Coming soon'), findsOneWidget);
    // warnIfMissed: false — IgnorePointer means this tap genuinely can't
    // hit "Apple" itself; that's the behavior under test.
    await tester.tap(find.text('Apple'), warnIfMissed: false);
    expect(tapped, isFalse);
  });

  testWidgets('A disabled row absorbs taps instead of letting them reach a widget behind it', (tester) async {
    var behindTapped = false;
    await tester.pumpWidget(MaterialApp(home: Center(child: Stack(
      children: [
        GestureDetector(onTap: () => behindTapped = true, child: Container(width: 300, height: 60, color: Colors.red)),
        StubProviderRow(
          icon: StubIcons.brandApple,
          label: 'Apple',
          enabled: false,
        ),
      ],
    ))));

    // warnIfMissed: false — the tap intentionally can't hit "Apple" itself
    // (IgnorePointer), which is exactly the behavior under test; what
    // matters is that it doesn't fall through to the widget behind it.
    await tester.tap(find.text('Apple'), warnIfMissed: false);
    expect(behindTapped, isFalse);
  });
}
