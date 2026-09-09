import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// The app's branded loading animation — a small ticket "prints out" of a
/// slot, torn edge and all, tying into the receipt-scanning theme instead
/// of a generic spinner. Use wherever the app shows an indeterminate
/// loading/processing state.
class StubLoadingIndicator extends StatefulWidget {
  const StubLoadingIndicator({super.key, this.size = 56});

  final double size;

  @override
  State<StubLoadingIndicator> createState() => _StubLoadingIndicatorState();
}

class _StubLoadingIndicatorState extends State<StubLoadingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pop = StubColors.gradPop(Theme.of(context).brightness);
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.3,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ReceiptPrinterPainter(progress: Curves.easeInOut.transform(_controller.value), gradient: pop),
        ),
      ),
    );
  }
}

class _ReceiptPrinterPainter extends CustomPainter {
  _ReceiptPrinterPainter({required this.progress, required this.gradient});

  /// 0 (fully retracted) to 1 (fully printed out).
  final double progress;
  final LinearGradient gradient;

  // Fixed regardless of theme — a printed paper ticket, like LockScreen's
  // bezel/paper treatment (see DESIGN.md §4).
  static const _slot = Color(0xFF1B1712);
  static const _paper = Color(0xFFF3ECDD);
  static const _ink = Color(0x331B1712);

  @override
  void paint(Canvas canvas, Size size) {
    final slotHeight = size.height * 0.16;
    final slotRect = Rect.fromLTWH(size.width * 0.08, 0, size.width * 0.84, slotHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(slotRect, const Radius.circular(3)),
      Paint()..color = _slot,
    );

    final maxPaperHeight = size.height - slotHeight;
    final paperHeight = maxPaperHeight * progress;
    if (paperHeight <= 4) return;

    final paperWidth = size.width * 0.66;
    final left = (size.width - paperWidth) / 2;
    final top = slotHeight - 2;
    const notchDepth = 5.0;
    const notches = 5;
    final notchWidth = paperWidth / notches;

    final path = Path()..moveTo(left, top);
    path.lineTo(left, top + paperHeight - notchDepth);
    for (var i = 0; i < notches; i++) {
      final x = left + notchWidth * (i + 0.5);
      final y = top + paperHeight - (i.isEven ? 0 : notchDepth);
      path.lineTo(x, y);
    }
    path.lineTo(left + paperWidth, top + paperHeight - notchDepth);
    path.lineTo(left + paperWidth, top);
    path.close();

    canvas.drawPath(path, Paint()..color = _paper);
    // The fixed cream paper color sits too close to the light theme's
    // background to read as a distinct shape there — a subtle fixed dark
    // outline (same tone as the slot) keeps the ticket visible against
    // either theme's background, not just dark's.
    canvas.drawPath(
      path,
      Paint()
        ..color = _slot.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final stripeRect = Rect.fromLTWH(left, top, paperWidth, 3);
    canvas.drawRect(stripeRect, Paint()..shader = gradient.createShader(stripeRect));

    final linePaint = Paint()
      ..color = _ink
      ..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      final lineY = top + 14 + i * 9.0;
      if (lineY > top + paperHeight - 8) break;
      canvas.drawLine(Offset(left + 7, lineY), Offset(left + paperWidth - 7, lineY), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReceiptPrinterPainter oldDelegate) => oldDelegate.progress != progress;
}
