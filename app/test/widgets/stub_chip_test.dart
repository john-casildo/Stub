import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_chip.dart';

void main() {
  testWidgets('StubChip shows its label and reports taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StubChip(label: 'Groceries', selected: false, onTap: () => tapped = true),
      ),
    );
    expect(find.text('Groceries'), findsOneWidget);
    await tester.tap(find.byType(StubChip));
    expect(tapped, isTrue);
  });
}
