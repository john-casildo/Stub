// One-off asset generator, not a real test — run explicitly with:
//   flutter test tool/generate_icon_test.dart
// Renders the StubLogo mark (DESIGN.md §7) onto a solid ink backplate at
// 1024x1024 and writes it to assets/icon/icon.png, which
// flutter_launcher_icons then uses to generate every platform's real icon
// sizes. Re-run this + `dart run flutter_launcher_icons` if the mark's
// geometry or colors ever change.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/theme/colors.dart';

const double _iconSize = 1024;

class _AppIconArt extends StatelessWidget {
  const _AppIconArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _iconSize,
      height: _iconSize,
      color: const Color(0xFF1B1712), // ink/phone-body dark backplate
      child: Center(
        child: SizedBox(
          width: _iconSize * 0.62,
          height: _iconSize * 0.62,
          child: CustomPaint(painter: _MarkPainter()),
        ),
      ),
    );
  }
}

/// Same geometry as StubLogo (lib/widgets/stub_logo.dart), duplicated here
/// deliberately — this file renders standalone via the test harness rather
/// than the real widget tree, and uses the dark-background gradient
/// variant since the icon backplate is always dark, not theme-reactive.
class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 1.0, h * 0.0)
      ..lineTo(w * 1.0, h * 1.0)
      ..lineTo(w * 0.0, h * 1.0)
      ..lineTo(w * 0.096, h * 0.833)
      ..lineTo(w * 0.0, h * 0.666)
      ..lineTo(w * 0.096, h * 0.5)
      ..lineTo(w * 0.0, h * 0.333)
      ..lineTo(w * 0.096, h * 0.166)
      ..lineTo(w * 0.0, h * 0.0)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [StubColors.accentDark, StubColors.gradSecondDark],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, fillPaint);

    final checkPath = Path()
      ..moveTo(w * (30 / 96), h * (50 / 96))
      ..lineTo(w * (44 / 96), h * (64 / 96))
      ..lineTo(w * (70 / 96), h * (34 / 96));

    final checkPaint = Paint()
      ..color = StubColors.onAccentDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * (9 / 96)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => false;
}

void main() {
  testWidgets('generate app icon PNG', (tester) async {
    tester.view.physicalSize = const Size(_iconSize, _iconSize);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(key: key, child: const _AppIconArt()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final file = File('assets/icon/icon.png');
      await file.writeAsBytes(bytes);
      // ignore: avoid_print
      print('Wrote ${file.path} (${bytes.length} bytes)');
    });
  });
}
