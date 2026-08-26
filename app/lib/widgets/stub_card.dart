import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// The one card surface style used everywhere (hero totals, category
/// lists, budget rows) — see DESIGN.md §6. Don't hand-roll a Container
/// with its own BoxDecoration in a screen file; use this.
class StubCard extends StatelessWidget {
  const StubCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? StubColors.surfaceDark : StubColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
