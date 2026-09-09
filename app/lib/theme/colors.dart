import 'package:flutter/material.dart';

/// Every value here is copied exactly from DESIGN.md — do not invent new
/// colors here or in a screen file. If a screen needs a color that isn't
/// listed, add it to DESIGN.md first, then here.
class StubColors {
  StubColors._();

  // ---- light ----
  static const bgLight = Color(0xFFECE7DC);
  static const bgWeaveLight = Color(0xFFE4DECE);
  static const surfaceLight = Color(0xFFFBF9F3);
  static const surfaceAltLight = Color(0xFFF3EFE3);
  static const inkLight = Color(0xFF211C15);
  static const lineLight = Color(0x21211C15); // ink @ ~13%
  static const accentLight = Color(0xFF0080FF);
  static const accentStrongLight = Color(0xFF0060B8);
  static const onAccentLight = Color(0xFFF5F9FF);
  static const goodLight = Color(0xFF4B7A5B);
  static const onGoodLight = Color(0xFFF1F6F2);
  static const dangerLight = Color(0xFFB03A2E);
  static const warnLight = Color(0xFF8C6A2F);
  static const gradSecondLight = Color(0xFF00D9B5);

  // ---- dark (same values whether via system dark mode or explicit toggle) ----
  static const bgDark = Color(0xFF0A0A0A);
  static const bgWeaveDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1A1A1A);
  static const surfaceAltDark = Color(0xFF242424);
  static const inkDark = Color(0xFFF3ECDD);
  static const lineDark = Color(0x24F3ECDD); // ink @ ~14%
  static const accentDark = Color(0xFF2E9CFF);
  static const accentStrongDark = Color(0xFF66B6FF);
  static const onAccentDark = Color(0xFF00243F);
  static const goodDark = Color(0xFF7FB88F);
  static const onGoodDark = Color(0xFF10241A);
  static const dangerDark = Color(0xFFE2776A);
  static const warnDark = Color(0xFFD3A85F);
  static const gradSecondDark = Color(0xFF34F5D0);

  /// Phone bezel — LockScreen's always-dark background (DESIGN.md
  /// `--phone-body`). Still theme-reactive like every other token here
  /// (light app theme gets the warm `#1B1712`, dark gets neutral
  /// near-black `#050505` matching bgDark's family) — it's just always a
  /// dark bezel regardless of which one applies.
  static const phoneBodyLight = Color(0xFF1B1712);
  static const phoneBodyDark = Color(0xFF050505);

  /// The one decorative gradient ("the pop") — see DESIGN.md §5 for exactly
  /// which elements this is allowed on. As of DESIGN.md §4/§5, every blue
  /// button uses this too — "never on a button" is no longer the rule.
  static LinearGradient gradPop(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        isDark ? accentDark : accentLight,
        isDark ? gradSecondDark : gradSecondLight,
      ],
    );
  }
}
