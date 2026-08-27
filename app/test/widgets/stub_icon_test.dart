import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stub/widgets/stub_icon.dart';

void main() {
  testWidgets('StubIcon renders an SvgPicture at the given size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StubIcon(StubIcons.home, size: 24, color: Colors.black),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('StubIcons has mail, brandApple, brandGoogle, and phone', (tester) async {
    for (final icon in [StubIcons.mail, StubIcons.brandApple, StubIcons.brandGoogle, StubIcons.phone]) {
      await tester.pumpWidget(MaterialApp(home: Center(child: StubIcon(icon, color: Colors.black))));
      expect(find.byType(SvgPicture), findsOneWidget);
    }
  });
}
