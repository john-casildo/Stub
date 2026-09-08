import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_loading_indicator.dart';

void main() {
  testWidgets('StubLoadingIndicator renders at the given size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: StubLoadingIndicator(size: 48))),
    );

    final size = tester.getSize(find.byType(StubLoadingIndicator));
    expect(size.width, 48);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('StubLoadingIndicator defaults to a reasonable size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: StubLoadingIndicator())),
    );

    expect(find.byType(StubLoadingIndicator), findsOneWidget);
  });

  testWidgets('StubLoadingIndicator animates repeatedly without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: StubLoadingIndicator())),
    );

    // A few explicit pumps through the repeating animation — not
    // pumpAndSettle, since a looping (repeat: true) controller never
    // settles.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(StubLoadingIndicator), findsOneWidget);
  });
}
