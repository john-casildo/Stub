import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_bottom_nav.dart';
import 'package:stub/widgets/stub_icon.dart';

void main() {
  testWidgets('StubBottomNav shows all items and reports taps', (tester) async {
    int? tappedIndex;
    var scanTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StubBottomNav(
          items: const [
            StubNavItem(icon: StubIcons.home, label: 'Home'),
            StubNavItem(icon: StubIcons.chartBar, label: 'Budgets'),
            StubNavItem(icon: StubIcons.userCircle, label: 'Profile'),
          ],
          activeIndex: 0,
          onTap: (i) => tappedIndex = i,
          onScanTap: () => scanTapped = true,
        ),
      ),
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Budgets'));
    expect(tappedIndex, 1);
  });
}
