// app/test/screens/scan_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/scan_screen.dart';

void main() {
  testWidgets('ScanScreen shows parsed fields and confirms on tap', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          merchant: 'Corner Market',
          amount: 18.42,
          category: 'Groceries',
          onClose: () {},
          onAddToLedger: () => confirmed = true,
        ),
      ),
    );
    expect(find.text('Corner Market'), findsOneWidget);
    expect(find.textContaining('18.42'), findsOneWidget);
    await tester.tap(find.text('Add to ledger'));
    expect(confirmed, isTrue);
  });
}
