import 'package:flutter_test/flutter_test.dart';
import 'package:stub/util/currency.dart';

void main() {
  test('formats a plain amount with two decimal places', () {
    expect(formatCurrency(18.42), r'$18.42');
  });

  test('inserts thousands separators', () {
    expect(formatCurrency(1842.30), r'$1,842.30');
  });

  test('inserts multiple thousands separators for large amounts', () {
    expect(formatCurrency(1234567.89), r'$1,234,567.89');
  });

  test('keeps the sign out of the thousands-separator grouping', () {
    expect(formatCurrency(-123.45), r'-$123.45');
    expect(formatCurrency(-1842.30), r'-$1,842.30');
  });

  test('formats zero', () {
    expect(formatCurrency(0), r'$0.00');
  });
}
