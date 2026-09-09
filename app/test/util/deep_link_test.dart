import 'package:flutter_test/flutter_test.dart';
import 'package:stub/util/deep_link.dart';

void main() {
  test('parses amount and merchant from a valid log-expense link', () {
    final result = parseDeepLink(Uri.parse('com.stubapp.stub://log-expense?amount=12.50&merchant=Starbucks'));
    expect(result, isNotNull);
    expect(result!.amount, 12.50);
    expect(result.merchant, 'Starbucks');
  });

  test('merchant is null when omitted', () {
    final result = parseDeepLink(Uri.parse('com.stubapp.stub://log-expense?amount=12.50'));
    expect(result, isNotNull);
    expect(result!.amount, 12.50);
    expect(result.merchant, isNull);
  });

  test('merchant is null when present but empty', () {
    final result = parseDeepLink(Uri.parse('com.stubapp.stub://log-expense?amount=12.50&merchant='));
    expect(result!.merchant, isNull);
  });

  test('amount is null when missing or malformed, not an error', () {
    final missing = parseDeepLink(Uri.parse('com.stubapp.stub://log-expense'));
    expect(missing!.amount, isNull);
    final malformed = parseDeepLink(Uri.parse('com.stubapp.stub://log-expense?amount=notanumber'));
    expect(malformed!.amount, isNull);
  });

  test('returns null for a link with a different host (e.g. the auth callback)', () {
    expect(parseDeepLink(Uri.parse('com.stubapp.stub://login-callback?code=abc')), isNull);
  });

  test('returns null for a completely unrelated URI', () {
    expect(parseDeepLink(Uri.parse('https://example.com')), isNull);
  });
}
