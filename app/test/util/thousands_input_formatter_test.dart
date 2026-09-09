import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/util/thousands_input_formatter.dart';

void main() {
  final formatter = ThousandsSeparatorInputFormatter();

  TextEditingValue format(String text) => formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
      );

  test('inserts thousands commas into the whole-number part', () {
    expect(format('1000000').text, '1,000,000');
    expect(format('1234').text, '1,234');
    expect(format('12').text, '12');
  });

  test('preserves a decimal part without adding commas to it', () {
    expect(format('1234567.89').text, '1,234,567.89');
  });

  test('rejects non-numeric input by returning the old value', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: '123'),
      const TextEditingValue(text: '12a3', selection: TextSelection.collapsed(offset: 4)),
    );
    expect(result.text, '123');
  });

  test('cursor stays after the same digit count once commas are inserted', () {
    // Typing "1000" with the cursor right after the first "1".
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '1000', selection: TextSelection.collapsed(offset: 1)),
    );
    expect(result.text, '1,000');
    expect(result.selection.baseOffset, 1);
  });
}
