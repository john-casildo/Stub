import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_hero_amount.dart';

void main() {
  testWidgets('StubHeroAmount renders the formatted amount at the given font size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: StubHeroAmount(amount: 1842.30, fontSize: 26)),
      ),
    );

    expect(find.text(r'$1,842.30'), findsOneWidget);
    final text = tester.widget<Text>(find.text(r'$1,842.30'));
    expect(text.style?.fontSize, 26);
  });

  testWidgets('StubHeroAmount wraps its text in a ShaderMask (gradient rendering)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: StubHeroAmount(amount: 42)),
      ),
    );

    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('StubHeroAmount stays a single Text/ShaderMask pair through the reveal animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: StubHeroAmount(amount: 1842.30, fontSize: 26)),
      ),
    );

    // Mid-animation.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text(r'$1,842.30'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);

    // Fully settled.
    await tester.pumpAndSettle();
    expect(find.text(r'$1,842.30'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
  });
}
