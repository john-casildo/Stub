import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/screens/root_shell.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';

void main() {
  testWidgets('RootShell starts on the ledger and switches to budgets on tab tap', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RootShell()));
    expect(find.text('LEFT TO SPEND'), findsOneWidget);

    await tester.tap(find.text('Budgets'));
    await tester.pump();
    expect(find.text('BUDGETED THIS MONTH'), findsOneWidget);
  });

  testWidgets('Profile tab shows Ledger content with the nav bar highlighting Home, not Profile', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RootShell()));

    await tester.tap(find.text('Profile'));
    await tester.pump();

    expect(find.text('LEFT TO SPEND'), findsOneWidget);
    final nav = tester.widget<StubBottomNav>(find.byType(StubBottomNav));
    expect(nav.activeIndex, 0);
  });

  testWidgets('Switching tabs cross-fades cleanly and settles on the new screen only', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RootShell()));

    await tester.tap(find.text('Budgets'));
    await tester.pumpAndSettle();

    expect(find.text('BUDGETED THIS MONTH'), findsOneWidget);
    expect(find.text('LEFT TO SPEND'), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('LEFT TO SPEND'), findsOneWidget);
    expect(find.text('BUDGETED THIS MONTH'), findsNothing);
  });
}
