import 'package:flutter/material.dart';
import '../theme/budget_status.dart';
import '../theme/colors.dart';

/// Linear budget progress bar. Gradient fill for the normal state; a flat
/// status color (`--warn` amber, or `--danger` red once at/over the
/// limit) for the other two — DESIGN.md §5: "a warning shouldn't be
/// dressed up decoratively."
class StubProgressBar extends StatelessWidget {
  const StubProgressBar({super.key, required this.progress, this.isWarning = false, this.height = 7})
      : status = null;

  /// Drives the fill color directly from a [BudgetStatus] instead of the
  /// legacy [isWarning] bool — lets a caller distinguish the new `danger`
  /// (at/over budget) tier from `warning` (approaching it).
  const StubProgressBar.status({super.key, required this.progress, required this.status, this.height = 7})
      : isWarning = false;

  final double progress;
  final bool isWarning;
  final double height;
  final BudgetStatus? status;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final track = isDark ? StubColors.surfaceAltDark : StubColors.surfaceAltLight;
    final statusColor = budgetStatusColor(status ?? (isWarning ? BudgetStatus.warning : BudgetStatus.normal), brightness);

    return LayoutBuilder(
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, animatedProgress, child) {
            final fillWidth = constraints.maxWidth * animatedProgress;
            return Container(
              height: height,
              decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(100)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: fillWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: statusColor,
                    gradient: statusColor == null ? StubColors.gradPop(brightness) : null,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
