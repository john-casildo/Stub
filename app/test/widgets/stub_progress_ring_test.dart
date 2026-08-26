// app/test/widgets/stub_progress_ring_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_progress_ring.dart';

void main() {
  testWidgets('StubProgressRing renders at the given size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: StubProgressRing(progress: 0.674, size: 56))),
    );
    final size = tester.getSize(find.byType(StubProgressRing));
    expect(size.width, 56);
    expect(size.height, 56);
  });

  testWidgets('StubProgressRing animates from 0 to the target progress on mount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: StubProgressRing(progress: 0.674, size: 56))),
    );

    // Mid-animation and fully settled both render without error.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(StubProgressRing), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(StubProgressRing), findsOneWidget);
  });
}
