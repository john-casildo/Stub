import 'package:flutter_test/flutter_test.dart';

import 'package:stub/main.dart';

void main() {
  testWidgets('App boots locked and unlocks into the ledger', (tester) async {
    await tester.pumpWidget(const StubApp());

    expect(find.text('Stub is locked'), findsOneWidget);

    await tester.tap(find.text('Unlock with Face ID'));
    await tester.pump();

    expect(find.text('LEFT TO SPEND'), findsOneWidget);
  });
}
