import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/screens/profile_screen.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';
import 'package:stub/widgets/stub_icon.dart';

const _navItems = [
  StubNavItem(icon: StubIcons.home, label: 'Home'),
  StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
  StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
];

void main() {
  testWidgets('ProfileScreen shows anonymous status, stats, and the account-link panel', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(
      accountLinkService: FakeAccountLinkService(),
      totalEverTracked: 1842.30,
      categoryCount: 4,
      activeNavIndex: 2,
      navItems: _navItems,
      onNavTap: (_) {},
      onScanTap: () {},
      onOpenSettings: () {},
    )));

    expect(find.textContaining('Anonymous'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget); // StubAccountLinkPanel's Email row
    expect(find.textContaining('4'), findsWidgets); // category count shown somewhere
  });

  testWidgets('ProfileScreen shows linked status and hides the link panel when not anonymous', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(
      accountLinkService: FakeAccountLinkService(isAnonymous: false, linkedEmail: 'me@example.com'),
      totalEverTracked: 1842.30,
      categoryCount: 4,
      activeNavIndex: 2,
      navItems: _navItems,
      onNavTap: (_) {},
      onScanTap: () {},
      onOpenSettings: () {},
    )));

    expect(find.textContaining('me@example.com'), findsOneWidget);
    expect(find.text('Email'), findsNothing); // panel not shown when already linked
  });

  testWidgets('Shows a prompt to add a name when none is set, and the set name once saved', (tester) async {
    final service = FakeAccountLinkService();
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(
      accountLinkService: service,
      totalEverTracked: 0,
      categoryCount: 0,
      activeNavIndex: 2,
      navItems: _navItems,
      onNavTap: (_) {},
      onScanTap: () {},
      onOpenSettings: () {},
    )));

    expect(find.textContaining('Add your name'), findsOneWidget);

    await tester.tap(find.textContaining('Add your name'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'First name'), 'Ada');
    await tester.enterText(find.widgetWithText(TextField, 'Last name'), 'Lovelace');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.firstName, 'Ada');
    expect(service.lastName, 'Lovelace');
    expect(find.text('Ada Lovelace'), findsOneWidget);
  });

  testWidgets('Tapping the Settings row calls onOpenSettings', (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(
      accountLinkService: FakeAccountLinkService(),
      totalEverTracked: 0,
      categoryCount: 0,
      activeNavIndex: 2,
      navItems: _navItems,
      onNavTap: (_) {},
      onScanTap: () {},
      onOpenSettings: () => opened = true,
    )));

    await tester.ensureVisible(find.text('Settings'));
    await tester.tap(find.text('Settings'));
    expect(opened, isTrue);
  });

  testWidgets('Rebuilds when the account-link service reports a status change', (tester) async {
    // `HttpAccountLinkService` fills its getters in from an async `/account`
    // fetch and then emits on `linkStatusChanges` — so the screen has to
    // rebuild on that event rather than trusting its first synchronous read.
    final service = FakeAccountLinkService();
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(
      accountLinkService: service,
      totalEverTracked: 0,
      categoryCount: 0,
      activeNavIndex: 2,
      navItems: _navItems,
      onNavTap: (_) {},
      onScanTap: () {},
      onOpenSettings: () {},
    )));

    expect(find.textContaining('later@example.com'), findsNothing);

    await service.linkEmail('later@example.com'); // emits on linkStatusChanges
    await tester.pumpAndSettle();

    expect(find.textContaining('later@example.com'), findsOneWidget);
  });
}
