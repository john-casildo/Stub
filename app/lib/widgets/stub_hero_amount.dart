import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/currency.dart';

/// A hero currency figure rendered as gradient text. DESIGN.md: "Blue =
/// gradient, always — there is no plain solid blue anywhere in this app."
/// Same ShaderMask + StubColors.gradPop technique as
/// stub_bottom_nav.dart's active tab label, applied to a `Text` instead of
/// a nav label. [fontSize] is exposed because hero amounts differ in size
/// across screens. Always wrapped in a shrink-to-fit `FittedBox` so a long
/// figure scales its font down instead of overflowing the row.
class StubHeroAmount extends StatelessWidget {
  const StubHeroAmount({super.key, required this.amount, this.fontSize = 26, this.currencyCode})
      : flatColor = null,
        _fraction = null;

  /// Same gradient-reveal hero treatment, but showing a percentage
  /// (e.g. "72%") instead of a formatted currency amount — used for the
  /// combined budget-progress hero on `LedgerScreen`. [flatColor], when
  /// given, replaces the gradient wipe with a plain fade-in in that
  /// color — the warn/danger budget-status override, same "no
  /// decorative gradient during a warning" rule as `StubProgressBar`.
  const StubHeroAmount.percent({super.key, required double fraction, this.fontSize = 26, this.flatColor})
      : amount = 0,
        currencyCode = null,
        // ignore: prefer_initializing_formals
        _fraction = fraction;

  final double amount;
  final double fontSize;
  final String? currencyCode;
  final Color? flatColor;
  final double? _fraction;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final pop = StubColors.gradPop(brightness);

    final text = _fraction == null ? formatCurrency(amount, currencyCode: currencyCode) : '${(_fraction * 100).round()}%';

    if (flatColor != null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (context, reveal, child) => Opacity(
            opacity: reveal,
            child: Text(text, style: StubText.unbounded(fontSize: fontSize, color: flatColor)),
          ),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (context, reveal, child) => ShaderMask(
          // Wipes the gradient in left-to-right: below `reveal`, the shader
          // outputs the real gradient colors (un-compressed — sampled from
          // where they'd naturally fall in the full 0..1 gradient), above
          // it, plain `ink` (matching modulate blend against the child's
          // white text = pass-through) — so the number reads immediately in
          // ink, and the gradient "paints on" from the left.
          shaderCallback: (rect) => LinearGradient(
            begin: pop.begin,
            end: pop.end,
            colors: [pop.colors[0], Color.lerp(pop.colors[0], pop.colors[1], reveal)!, ink, ink],
            stops: [0, reveal, reveal, 1],
          ).createShader(rect),
          child: child,
        ),
        child: Text(text, style: StubText.unbounded(fontSize: fontSize, color: Colors.white)),
      ),
    );
  }
}
