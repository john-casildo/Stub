import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/budget_status.dart';
import '../theme/colors.dart';

/// Circular progress indicator — the dashboard's "left to spend" ring.
/// Gradient stroke for the normal state (DESIGN.md §5: one of the fixed
/// gradient uses); a flat status color (warn amber / danger red) once
/// [status] leaves `BudgetStatus.normal`, same "no decorative gradient
/// during a warning" rule `StubProgressBar` follows.
class StubProgressRing extends StatelessWidget {
  const StubProgressRing({
    super.key,
    required this.progress,
    this.size = 56,
    this.strokeWidth = 6,
    this.status = BudgetStatus.normal,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final statusColor = budgetStatusColor(status, brightness);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, child) => CustomPaint(
          painter: _RingPainter(
            progress: animatedProgress,
            strokeWidth: strokeWidth,
            trackColor: isDark ? StubColors.lineDark : StubColors.lineLight,
            gradient: statusColor == null ? StubColors.gradPop(brightness) : null,
            flatColor: statusColor,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    this.gradient,
    this.flatColor,
  }) : assert(gradient != null || flatColor != null);

  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final LinearGradient? gradient;
  final Color? flatColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    if (flatColor != null) {
      fillPaint.color = flatColor!;
    } else {
      fillPaint.shader = gradient!.createShader(rect);
    }

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.gradient != gradient || oldDelegate.flatColor != flatColor;
}
