import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'stub_icon.dart';

/// Label-over-value row used on Edit Entry and Manual Entry — see the
/// `.field-row` pattern in DESIGN.md's component inventory (CLAUDE.md).
class StubFieldRow extends StatelessWidget {
  const StubFieldRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
    this.editable = false,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;
  final bool editable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final ink30 = ink.withValues(alpha: 0.3);
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;

    final valueStyle = mono
        ? StubText.unbounded(fontSize: 16, color: valueColor ?? ink)
        : StubText.archivo(fontSize: 16, fontWeight: FontWeight.w600, color: valueColor ?? ink);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: line))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink50)),
                  const SizedBox(height: 6),
                  Text(value, style: valueStyle),
                ],
              ),
            ),
            if (editable) StubIcon(StubIcons.pencil, size: 14, color: ink30),
          ],
        ),
      ),
    );
  }
}
