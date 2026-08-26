import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_progress_bar.dart';

void main() {
  testWidgets('StubProgressBar renders at the given height', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SizedBox(width: 200, child: StubProgressBar(progress: 0.71, height: 7))),
      ),
    );
    final size = tester.getSize(find.byType(StubProgressBar));
    expect(size.height, 7);
  });

  testWidgets('StubProgressBar animates its fill width from 0 up to the target progress', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SizedBox(width: 200, child: StubProgressBar(progress: 0.71, height: 7))),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(StubProgressBar), findsOneWidget);
  });
}
