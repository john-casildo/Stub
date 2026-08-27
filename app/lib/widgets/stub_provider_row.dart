import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'stub_icon.dart';
import 'stub_pressable.dart';

class StubProviderRow extends StatelessWidget {
  const StubProviderRow({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    this.onTap,
  });

  final String icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final color = enabled ? ink : ink.withValues(alpha: 0.3);

    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          StubIcon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: StubText.archivo(fontSize: 15, fontWeight: FontWeight.w600, color: color))),
          if (!enabled)
            Text('Coming soon', style: StubText.archivo(fontSize: 12, color: ink.withValues(alpha: 0.4))),
        ],
      ),
    );

    if (!enabled) {
      return Semantics(
        enabled: false,
        label: '$label, coming soon',
        child: IgnorePointer(child: row),
      );
    }
    return StubPressable(onTap: onTap, child: row);
  }
}
