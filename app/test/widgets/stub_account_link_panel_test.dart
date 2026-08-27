import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/account_link_service.dart';
import 'package:stub/widgets/stub_account_link_panel.dart';

class _ThrowingAccountLinkService implements AccountLinkService {
  @override
  bool get isAnonymous => true;
  @override
  String? get linkedEmail => null;
  @override
  Future<void> linkEmail(String email) async => throw Exception('network error');
  @override
  Stream<bool> get linkStatusChanges => const Stream.empty();
}

void main() {
  testWidgets('A failed linkEmail call shows an error and does not call onLinked', (tester) async {
    var linked = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StubAccountLinkPanel(
      accountLinkService: _ThrowingAccountLinkService(),
      onLinked: () => linked = true,
    ))));

    await tester.tap(find.text('Email'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'me@example.com');
    await tester.tap(find.text('Send link'));
    await tester.pump();

    expect(find.textContaining("Couldn't send the link"), findsOneWidget);
    expect(linked, isFalse);
  });

  testWidgets('An invalid email shows a validation message without calling the service', (tester) async {
    var called = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StubAccountLinkPanel(
      accountLinkService: _ThrowingAccountLinkService(), // would throw if reached — proves it wasn't called
      onLinked: () => called = true,
    ))));

    await tester.tap(find.text('Email'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tester.tap(find.text('Send link'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(called, isFalse);
  });
}
