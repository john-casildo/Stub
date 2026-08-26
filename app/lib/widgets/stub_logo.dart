import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// The app's one logo mark — torn stub + check. See DESIGN.md §7 for why
/// this is the final choice and the exact geometry spec. This is the only
/// place that geometry should be defined in Dart; reuse this widget rather
/// than re-drawing the shape somewhere else.
class StubLogo extends StatelessWidget {
  const StubLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return CustomPaint(
      size: Size.square(size),
      painter: _StubLogoPainter(
        gradient: StubColors.gradPop(brightness),
        checkColor: brightness == Brightness.dark
            ? StubColors.onAccentDark
            : StubColors.onAccentLight,
      ),
    );
  }
}

class _StubLogoPainter extends CustomPainter {
  _StubLogoPainter({required this.gradient, required this.checkColor});

  final LinearGradient gradient;
  final Color checkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Torn-edge polygon — same relative points as the CSS clip-path in
    // DESIGN.md §7: 100% 0, 100% 100%, 0 100%, 9.6% 83.3%, 0 66.6%,
    // 9.6% 50%, 0 33.3%, 9.6% 16.6%, 0 0.
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
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, fillPaint);

    // Checkmark — same relative points as the SVG in DESIGN.md §7:
    // M30 50 L44 64 L70 34 on a 96x96 reference box.
    final checkPath = Path()
      ..moveTo(w * (30 / 96), h * (50 / 96))
      ..lineTo(w * (44 / 96), h * (64 / 96))
      ..lineTo(w * (70 / 96), h * (34 / 96));

    final checkPaint = Paint()
      ..color = checkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * (8 / 96)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _StubLogoPainter oldDelegate) =>
      oldDelegate.gradient != gradient || oldDelegate.checkColor != checkColor;
}
