import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'stub_icon.dart';
import 'stub_pressable.dart';

class StubNavItem {
  const StubNavItem({required this.icon, required this.label});

  final String icon;
  final String label;
}

/// Bottom nav bar. Active tab: icon is solid `accentStrong` (DESIGN.md §4's
/// documented exception — SVG `currentColor` can't use the gradient-text
/// trick), label is true gradient text via ShaderMask.
class StubBottomNav extends StatelessWidget {
  const StubBottomNav({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onTap,
    required this.onScanTap,
  }) : assert(items.length == 3, 'StubBottomNav takes exactly 3 items — the scan button is fixed in the middle, not one of them.');

  final List<StubNavItem> items;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final ink30 = (isDark ? StubColors.inkDark : StubColors.inkLight).withValues(alpha: 0.3);
    final accentStrong = isDark ? StubColors.accentStrongDark : StubColors.accentStrongLight;
    final onAccent = isDark ? StubColors.onAccentDark : StubColors.onAccentLight;
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;
    final bg = isDark ? StubColors.bgDark : StubColors.bgLight;

    Widget buildItem(int index) {
      final item = items[index];
      final active = index == activeIndex;

      final iconAndLabel = Column(
        key: ValueKey(active),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StubIcon(item.icon, size: 18, color: active ? accentStrong : ink30),
          const SizedBox(height: 4),
          active
              ? ShaderMask(
                  shaderCallback: (rect) => StubColors.gradPop(brightness).createShader(rect),
                  child: Text(item.label, style: StubText.archivo(fontSize: 11, color: Colors.white).copyWith(height: 1.0)),
                )
              : Text(item.label, style: StubText.archivo(fontSize: 11, color: ink30).copyWith(height: 1.0)),
        ],
      );

      return StubPressable(
        onTap: () => onTap(index),
        child: SizedBox(
          width: 48,
          height: 44,
          child: _BumpScale(
            trigger: active,
            child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: iconAndLabel),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: line)), color: bg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          buildItem(0),
          StubPressable(
            key: const Key('stub-bottom-nav-scan-button'),
            onTap: onScanTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: StubColors.gradPop(brightness)),
              child: Center(child: StubIcon(StubIcons.camera, size: 20, color: onAccent)),
            ),
          ),
          buildItem(1),
          buildItem(2),
        ],
      ),
    );
  }
}

/// Plays a one-shot scale bump (1.0 -> 1.15 -> 1.0) every time [trigger]
/// changes value — used to punctuate a bottom-nav item flipping active.
class _BumpScale extends StatefulWidget {
  const _BumpScale({required this.trigger, required this.child});

  final Object trigger;
  final Widget child;

  @override
  State<_BumpScale> createState() => _BumpScaleState();
}

class _BumpScaleState extends State<_BumpScale> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 60),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant _BumpScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
      child: widget.child,
    );
  }
}
