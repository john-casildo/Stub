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
    await tester.tap(find.text('Apple'));
    expect(tapped, isFalse);
  });
}
