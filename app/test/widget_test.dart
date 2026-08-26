// Smoke test: confirms the app boots and the theme/button wiring renders
// without throwing. Expand this as real screens replace _ThemeCheckScreen.

import 'package:flutter_test/flutter_test.dart';

import 'package:stub/main.dart';

void main() {
  testWidgets('App boots and shows the Stub wordmark', (WidgetTester tester) async {
    await tester.pumpWidget(const StubApp());

    expect(find.text('Stub'), findsOneWidget);
    expect(find.text('Add to ledger'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });
}
