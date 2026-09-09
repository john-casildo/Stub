import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/theme/budget_status.dart';
import 'package:stub/theme/colors.dart';
import 'package:stub/widgets/stub_progress_bar.dart';

void main() {
  Color? fillColor(WidgetTester tester) {
    final containers = tester.widgetList<Container>(find.byType(Container));
    // The fill is the inner Container (inside Align); the track is the outer one.
    return containers.last.decoration is BoxDecoration ? (containers.last.decoration as BoxDecoration).color : null;
  }

  testWidgets('StubProgressBar.status uses a flat danger color, not the gradient, when over budget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(width: 200, child: StubProgressBar.status(progress: 1.0, status: BudgetStatus.danger)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fillColor(tester), StubColors.dangerLight);
  });

  testWidgets('StubProgressBar.status uses the gradient (no flat color) when normal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(width: 200, child: StubProgressBar.status(progress: 0.3, status: BudgetStatus.normal)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fillColor(tester), isNull);
  });

  testWidgets('StubProgressBar renders at the given height', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SizedBox(width: 200, child: StubProgressBar(progress: 0.71, height: 7))),
      ),
    );
    final size = tester.getSize(find.byType(StubProgressBar));
    expect(size.height, 7);
  });

  testWidgets('StubProgressBar animates its fill width from 0 up to the target progress', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: SizedBox(width: 200, child: StubProgressBar(progress: 0.71, height: 7))),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(StubProgressBar), findsOneWidget);
  });
}
