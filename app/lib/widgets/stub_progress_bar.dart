import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Linear budget progress bar. Gradient fill for the normal state; solid
/// `--warn` amber for the over-budget state — DESIGN.md §5: "a warning
/// shouldn't be dressed up decoratively."
class StubProgressBar extends StatelessWidget {
  const StubProgressBar({super.key, required this.progress, this.isWarning = false, this.height = 7});

  final double progress;
  final bool isWarning;
  final double height;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final track = isDark ? StubColors.surfaceAltDark : StubColors.surfaceAltLight;
    final warnColor = isDark ? StubColors.warnDark : StubColors.warnLight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fillWidth = constraints.maxWidth * progress.clamp(0.0, 1.0);
        return Container(
          height: height,
          decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(100)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: fillWidth,
              height: height,
              decoration: BoxDecoration(
                color: isWarning ? warnColor : null,
                gradient: isWarning ? null : StubColors.gradPop(brightness),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        );
      },
    );
  }
}
