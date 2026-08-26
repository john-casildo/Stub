import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';

/// Category filter chip — selected state uses the gradient fill (DESIGN.md
/// §5: "the active category filter chip" is one of the listed gradient
/// uses), unselected is a plain outlined pill.
class StubChip extends StatelessWidget {
  const StubChip({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;
    final surfaceAlt = isDark ? StubColors.surfaceAltDark : StubColors.surfaceAltLight;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final onAccent = isDark ? StubColors.onAccentDark : StubColors.onAccentLight;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: selected ? null : Border.all(color: line),
          color: selected ? null : surfaceAlt,
          gradient: selected ? StubColors.gradPop(brightness) : null,
        ),
        child: Text(
          label,
          style: StubText.archivo(
            fontSize: 13,
            color: selected ? onAccent : ink.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
