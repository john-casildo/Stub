import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/root_shell.dart';

void main() {
  testWidgets('RootShell starts on the ledger and switches to budgets on tab tap', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RootShell()));
    expect(find.text('LEFT TO SPEND'), findsOneWidget);

    await tester.tap(find.text('Budgets'));
    await tester.pump();
    expect(find.text('BUDGETED THIS MONTH'), findsOneWidget);
  });
}
