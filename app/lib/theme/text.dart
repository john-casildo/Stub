import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Exactly three fonts per DESIGN.md §1, each with one job. Do not reach
/// for a fourth font in a screen file; if something needs different
/// treatment, it's a weight/size change on one of these three, not a new
/// font import.
class StubText {
  StubText._();

  /// Body/UI text — labels, buttons, nav, captions, headings. The default
  /// for everything that isn't a currency number or the brand wordmark.
  static TextStyle archivo({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
  }) =>
      GoogleFonts.archivo(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// The brand wordmark ONLY — "Stub" itself (app bar / screen brand label)
  /// and the widget's "Stub · [month]" subtitle. Never use for a generic
  /// section heading; those are archivo().
  static TextStyle domine({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) =>
      GoogleFonts.domine(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  /// Currency numbers only — hero amounts, list amounts, budget figures,
  /// field values. See DESIGN.md §1: "if it's a dollar figure, it's
  /// Unbounded." Never use for labels or non-numeric text.
  static TextStyle unbounded({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.2,
  }) =>
      GoogleFonts.unbounded(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
