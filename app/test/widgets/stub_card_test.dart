import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_card.dart';

void main() {
  testWidgets('StubCard renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: StubCard(child: Text('hello'))),
    );
    expect(find.text('hello'), findsOneWidget);
  });
}
