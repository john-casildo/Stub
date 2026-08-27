import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stub/data/fakes.dart';
import 'package:stub/data/local_prefs.dart';
import 'package:stub/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App boots locked and unlocks into the ledger', (tester) async {
    // Backup prompt already seen — this test only covers the plain
    // lock/unlock transition, not the one-time prompt.
    SharedPreferences.setMockInitialValues({'has_seen_backup_prompt': true});

    await tester.pumpWidget(StubApp(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      localPrefs: LocalPrefs(),
    ));

    expect(find.text('Stub is locked'), findsOneWidget);

    await tester.tap(find.text('Unlock with Face ID'));
    await tester.pumpAndSettle();

    expect(find.text('LEFT TO SPEND'), findsOneWidget);
  });

  testWidgets('First unlock shows the backup prompt before the ledger; skipping continues past it', (tester) async {
    await tester.pumpWidget(StubApp(
      categoryRepository: FakeCategoryRepository(),
      transactionRepository: FakeTransactionRepository(),
      budgetRepository: FakeBudgetRepository(),
      accountLinkService: FakeAccountLinkService(),
      localPrefs: LocalPrefs(),
    ));

    await tester.tap(find.text('Unlock with Face ID'));
    await tester.pump();

    expect(find.text('Back up your data'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('LEFT TO SPEND'), findsOneWidget);
  });
}
