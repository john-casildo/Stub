import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_field_row.dart';

void main() {
  testWidgets('StubFieldRow shows label and value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StubFieldRow(label: 'Merchant', value: 'Corner Market'),
      ),
    );
    expect(find.text('MERCHANT'), findsOneWidget);
    expect(find.text('Corner Market'), findsOneWidget);
  });
}
