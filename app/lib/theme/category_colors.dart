import 'package:flutter/material.dart';

const _lightPalette = [
  Color(0xFF5B6B8C),
  Color(0xFF7A5B7A),
  Color(0xFFA68A3E),
  Color(0xFF4F7A78),
  Color(0xFFA15C43),
  Color(0xFF6B5B95),
];

const _darkPalette = [
  Color(0xFF8CA0C7),
  Color(0xFFB08CB0),
  Color(0xFFD4B75E),
  Color(0xFF7CBAB7),
  Color(0xFFD08A6E),
  Color(0xFFA395C9),
];

/// Deterministic category swatch color — cycles through a fixed 6-color
/// palette by [index] (a category's position in creation order). See
/// DESIGN.md §2 "Category swatch palette" — not semantically reserved
/// like accent/good/warn/danger.
Color categoryColor(int index, Brightness brightness) {
  final palette = brightness == Brightness.dark ? _darkPalette : _lightPalette;
  return palette[index % palette.length];
}
