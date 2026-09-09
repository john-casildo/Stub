// One-off asset generator, not a real test — run explicitly with:
//   flutter test tool/generate_launch_image_test.dart
// Renders the StubLogo mark (DESIGN.md §7) alone (transparent background —
// each platform's launch screen config supplies the actual background
// color) at a fixed logical size and writes 1x/2x/3x PNGs straight into
// each platform's launch-screen asset slots. Re-run this if the mark's
// geometry or colors ever change.
//
// Same mark geometry/colors as tool/generate_icon_test.dart's
// _MarkPainter, duplicated deliberately — this renders standalone via the
// test harness, not the real widget tree.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/theme/colors.dart';

/// Logical (1x) size in points/dp — matches LaunchScreen.storyboard's
/// declared LaunchImage size and is what Android's launch_background.xml
/// bitmap renders at via drawable-nodpi (no density scaling).
const double _logicalSize = 120;

class _LaunchMark extends StatelessWidget {
  const _LaunchMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _logicalSize,
      height: _logicalSize,
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

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

Future<void> _writePng(WidgetTester tester, double pixelRatio, String path) async {
  tester.view.physicalSize = Size(_logicalSize * pixelRatio, _logicalSize * pixelRatio);
  tester.view.devicePixelRatio = pixelRatio;

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(key: key, child: const _LaunchMark()),
    ),
  );
  await tester.pumpAndSettle();

  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    // ignore: avoid_print
    print('Wrote $path (${bytes.length} bytes)');
  });
}

void main() {
  testWidgets('generate launch-screen mark PNGs', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // iOS: LaunchScreen.storyboard's declared LaunchImage size must
    // match _logicalSize (square) — keep both in sync if either changes.
    await _writePng(tester, 1, 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png');
    await _writePng(tester, 2, 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png');
    await _writePng(tester, 3, 'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png');

    // Android: drawable-nodpi means no density scaling, so a single 1x
    // (logical-size) PNG is correct here.
    await _writePng(tester, 1, 'android/app/src/main/res/drawable-nodpi/launch_image.png');
  });
}
