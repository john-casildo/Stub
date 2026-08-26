import 'package:flutter/material.dart';
import 'colors.dart';
import 'text.dart';

/// Builds the app's light/dark ThemeData from DESIGN.md's tokens. Screens
/// should pull colors from Theme.of(context).colorScheme /
/// StubColors.gradPop(...), not hardcode a hex value inline.
class StubTheme {
  StubTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? StubColors.bgDark : StubColors.bgLight;
    final surface = isDark ? StubColors.surfaceDark : StubColors.surfaceLight;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final accent = isDark ? StubColors.accentDark : StubColors.accentLight;
    final onAccent = isDark ? StubColors.onAccentDark : StubColors.onAccentLight;
    final good = isDark ? StubColors.goodDark : StubColors.goodLight;
    final onGood = isDark ? StubColors.onGoodDark : StubColors.onGoodLight;
    final danger = isDark ? StubColors.dangerDark : StubColors.dangerLight;
    final line = isDark ? StubColors.lineDark : StubColors.lineLight;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Archivo',
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: onAccent,
        secondary: good,
        onSecondary: onGood,
        error: danger,
        onError: onAccent,
        surface: surface,
        onSurface: ink,
      ),
      dividerColor: line,
      textTheme: TextTheme(
        bodyMedium: StubText.archivo(fontSize: 14, color: ink),
        bodySmall: StubText.archivo(fontSize: 12, color: ink.withValues(alpha: 0.6)),
        titleLarge: StubText.domine(fontSize: 22, color: ink),
        labelLarge: StubText.archivo(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
      ),
      // Add-type actions (see DESIGN.md §4): blue, the app's main color.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          textStyle: StubText.archivo(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
