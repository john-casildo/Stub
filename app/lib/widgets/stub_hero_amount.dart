import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/currency.dart';

/// A hero currency figure rendered as gradient text. DESIGN.md: "Blue =
/// gradient, always — there is no plain solid blue anywhere in this app."
/// Same ShaderMask + StubColors.gradPop technique as
/// stub_bottom_nav.dart's active tab label, applied to a `Text` instead of
/// a nav label. [fontSize] is exposed because hero amounts differ in size
/// across screens.
class StubHeroAmount extends StatelessWidget {
  const StubHeroAmount({super.key, required this.amount, this.fontSize = 26});

  final double amount;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ShaderMask(
      shaderCallback: (rect) => StubColors.gradPop(brightness).createShader(rect),
      child: Text(
        formatCurrency(amount),
        style: StubText.unbounded(fontSize: fontSize, color: Colors.white),
      ),
    );
  }
}
