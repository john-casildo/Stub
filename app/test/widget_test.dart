import 'package:flutter_test/flutter_test.dart';

import 'package:stub/data/fakes.dart';
import 'package:stub/main.dart';

void main() {
  testWidgets('App boots locked and unlocks into the ledger', (tester) async {
    await tester.pumpWidget(StubApp(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
    ));

    expect(find.text('Stub is locked'), findsOneWidget);

    await tester.tap(find.text('Unlock with Face ID'));
    await tester.pumpAndSettle();

    expect(find.text('LEFT TO SPEND'), findsOneWidget);
  });
}
