import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'stub_icon.dart';

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
      return GestureDetector(
        onTap: () => onTap(index),
        child: SizedBox(
          width: 48,
          height: 44,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StubIcon(item.icon, size: 18, color: active ? accentStrong : ink30),
              const SizedBox(height: 4),
              active
                  ? ShaderMask(
                      shaderCallback: (rect) => StubColors.gradPop(brightness).createShader(rect),
                      child: Text(item.label, style: StubText.archivo(fontSize: 11, color: Colors.white)),
                    )
                  : Text(item.label, style: StubText.archivo(fontSize: 11, color: ink30)),
            ],
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
          GestureDetector(
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
