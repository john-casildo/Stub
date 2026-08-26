import 'package:flutter/material.dart';

/// Wraps [child] with press feedback (scale + fade down while held) and,
/// when [ensureMinTapSize] is true, pads the hit area up to the 44x44
/// minimum tap-target guideline without changing [child]'s visible size.
///
/// Used instead of `InkWell` because most tappable surfaces in this app
/// (gradient chips, the gradient scan button, the gradient unlock button)
/// paint an opaque fill that would hide a Material ripple underneath it.
class StubPressable extends StatefulWidget {
  const StubPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.ensureMinTapSize = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool ensureMinTapSize;

  @override
  State<StubPressable> createState() => _StubPressableState();
}

class _StubPressableState extends State<StubPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );

    if (widget.ensureMinTapSize) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(child: content),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: content,
    );
  }
}
