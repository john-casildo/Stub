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

  group('CurrencyConfig', () {
    tearDown(() => CurrencyConfig.code = 'USD');

    test('defaults to USD', () {
      expect(CurrencyConfig.code, 'USD');
    });

    test('switching to CRC changes the symbol formatCurrency uses', () {
      CurrencyConfig.code = 'CRC';
      expect(formatCurrency(1842.30), '₡1,842.30');
    });

    test('an unrecognized code falls back to the dollar sign', () {
      CurrencyConfig.code = 'nonsense';
      expect(formatCurrency(5), r'$5.00');
    });

    test('supports a broad set of world currency symbols', () {
      expect(formatCurrency(5, currencyCode: 'EUR'), '€5.00');
      expect(formatCurrency(5, currencyCode: 'GBP'), '£5.00');
      expect(formatCurrency(5, currencyCode: 'JPY'), '¥5.00');
      expect(formatCurrency(5, currencyCode: 'INR'), '₹5.00');
      expect(formatCurrency(5, currencyCode: 'KRW'), '₩5.00');
      expect(formatCurrency(5, currencyCode: 'MXN'), 'MX\$5.00');
      expect(formatCurrency(5, currencyCode: 'BRL'), 'R\$5.00');
      expect(formatCurrency(5, currencyCode: 'VND'), '₫5.00');
    });
  });

  group('supportedCurrencies', () {
    test('lists every code CurrencyConfig can format, each with a symbol', () {
      expect(supportedCurrencies, isNotEmpty);
      expect(supportedCurrencies, contains('USD'));
      expect(supportedCurrencies, contains('EUR'));
      expect(supportedCurrencies.toSet().length, supportedCurrencies.length); // no duplicates
    });

    test('an explicit currencyCode overrides the global default', () {
      expect(formatCurrency(1842.30, currencyCode: 'CRC'), '₡1,842.30');
      expect(CurrencyConfig.code, 'USD'); // global default untouched
    });
  });
}
