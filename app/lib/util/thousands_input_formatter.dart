import 'package:flutter/services.dart';

/// Live-formats a numeric text field with thousands commas as the user
/// types (e.g. "1000000" -> "1,000,000"), while still allowing a single
/// decimal point. Callers must strip the commas back out (`.replaceAll(',',
/// '')`) before `double.tryParse`-ing the field's text.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  /// When given, a keystroke that would push the field's parsed value
  /// above this cap is rejected outright (the field just doesn't change)
  /// rather than letting the user type an over-limit number and finding
  /// out only when Save rejects it — the same sanity-cap value every
  /// amount/limit field in the app already enforces at save time.
  ThousandsSeparatorInputFormatter({this.maxValue});

  final double? maxValue;

  static final _validCharacters = RegExp(r'^\d*\.?\d*$');
  static final _digitOrDot = RegExp(r'[\d.]');
  static final _nonDigitOrDot = RegExp(r'[^\d.]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final raw = newValue.text.replaceAll(',', '');
    if (!_validCharacters.hasMatch(raw)) return oldValue;

    final max = maxValue;
    if (max != null) {
      final parsed = double.tryParse(raw);
      if (parsed != null && parsed > max) return oldValue;
    }

    final parts = raw.split('.');
    final wholePart = parts[0];
    final decimalPart = parts.length > 1 ? '.${parts[1]}' : '';

    final buffer = StringBuffer();
    for (var i = 0; i < wholePart.length; i++) {
      final remaining = wholePart.length - i;
      if (i > 0 && remaining % 3 == 0) buffer.write(',');
      buffer.write(wholePart[i]);
    }
    final formatted = '${buffer.toString()}$decimalPart';

    // Preserve cursor position by keeping it after the same count of
    // digits/decimal-point it was after before reformatting.
    final digitsBeforeCursor =
        newValue.text.substring(0, newValue.selection.end).replaceAll(_nonDigitOrDot, '').length;
    var seen = 0;
    var newOffset = formatted.length;
    for (var i = 0; i < formatted.length; i++) {
      if (_digitOrDot.hasMatch(formatted[i])) seen++;
      if (seen == digitsBeforeCursor) {
        newOffset = i + 1;
        break;
      }
    }

    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: newOffset));
  }
}
