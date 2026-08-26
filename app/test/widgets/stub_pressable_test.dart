import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_pressable.dart';

void main() {
  testWidgets('StubPressable reports taps and enforces a 44x44 minimum tap size', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: StubPressable(
            onTap: () => tapped = true,
            ensureMinTapSize: true,
            child: const SizedBox(width: 10, height: 10, child: Text('x')),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(StubPressable));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));

    await tester.tap(find.byType(StubPressable));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
