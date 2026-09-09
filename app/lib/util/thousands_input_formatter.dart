import 'package:flutter/services.dart';

/// Live-formats a numeric text field with thousands commas as the user
/// types (e.g. "1000000" -> "1,000,000"), while still allowing a single
/// decimal point. Callers must strip the commas back out (`.replaceAll(',',
/// '')`) before `double.tryParse`-ing the field's text.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final _validCharacters = RegExp(r'^\d*\.?\d*$');
  static final _digitOrDot = RegExp(r'[\d.]');
  static final _nonDigitOrDot = RegExp(r'[^\d.]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final raw = newValue.text.replaceAll(',', '');
    if (!_validCharacters.hasMatch(raw)) return oldValue;

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
