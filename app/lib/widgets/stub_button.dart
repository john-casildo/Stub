import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';

/// Primary button, per DESIGN.md §4 / CLAUDE.md component inventory.
/// - [StubButtonVariant.add]  → blue, the app's main color (creating something new)
/// - [StubButtonVariant.save] → green (confirming/persisting an edit)
///
/// This mirrors the mockup's `.cta` / `.cta.save` split. Do not build a
/// second button widget for a new screen — add a variant here if a
/// genuinely new case shows up, the way `save` was added to `add`.
enum StubButtonVariant { add, save }

class StubButton extends StatelessWidget {
  const StubButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StubButtonVariant.add,
  });

  final String label;
  final VoidCallback? onPressed;
  final StubButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final bool isSave = variant == StubButtonVariant.save;

    final Color foreground = isSave
        ? (isDark ? StubColors.onGoodDark : StubColors.onGoodLight)
        : (isDark ? StubColors.onAccentDark : StubColors.onAccentLight);

    // `add` is blue, and DESIGN.md requires blue to always be the gradient
    // (never a flat color) — so its background comes from a BoxDecoration
    // behind a transparent ElevatedButton, not from ElevatedButton's own
    // (flat-only) backgroundColor.
    final Color? flatBackground =
        isSave ? (isDark ? StubColors.goodDark : StubColors.goodLight) : null;

    final button = SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: flatBackground ?? Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: Text(label, style: StubText.archivo(fontSize: 15, fontWeight: FontWeight.w600, color: foreground)),
      ),
    );

    if (isSave) return button;

    return Container(
      decoration: BoxDecoration(
        gradient: StubColors.gradPop(brightness),
        borderRadius: BorderRadius.circular(10),
      ),
      child: button,
    );
  }
}
