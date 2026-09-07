// app/test/util/receipt_parser_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/text_recognition_service.dart';
import 'package:stub/util/receipt_parser.dart';

RecognizedLine _line(String text, {double top = 0, double left = 0, double height = 20}) =>
    RecognizedLine(text: text, boundingBox: Rect.fromLTWH(left, top, 100, height));

void main() {
  group('redactLongDigitRuns', () {
    test('masks a run of 8+ digits, keeping the last 4', () {
      expect(redactLongDigitRuns('Card ending 123456789012'), 'Card ending ••••9012');
    });

    test('leaves short digit runs untouched', () {
      expect(redactLongDigitRuns('Total 12.99, Qty 2'), 'Total 12.99, Qty 2');
    });
  });

  group('parseReceiptLines', () {
    test('returns all-null fields for an empty list', () {
      final result = parseReceiptLines(const []);
      expect(result.merchant, isNull);
      expect(result.amount, isNull);
      expect(result.occurredAt, isNull);
    });

    test('extracts merchant as the first line in reading order, amount, and date', () {
      final lines = [
        _line('Corner Market', top: 0),
        _line('01/15/2026', top: 20),
        _line('Total \$45.99', top: 40),
      ];
      final result = parseReceiptLines(lines);
      expect(result.merchant, 'Corner Market');
      expect(result.amount, 45.99);
      expect(result.occurredAt, DateTime(2026, 1, 15));
    });

    test('reconstructs reading order from scrambled input using position, not list order', () {
      // Listed out of order, but positioned top-to-bottom correctly —
      // merchant must come from the top-most line, not lines[0].
      final lines = [
        _line('Total \$10.00', top: 40),
        _line('Corner Market', top: 0),
      ];
      final result = parseReceiptLines(lines);
      expect(result.merchant, 'Corner Market');
    });

    test('prefers a line containing "total" over a larger unrelated number', () {
      final lines = [
        _line('Item A \$99.00', top: 0),
        _line('Total \$10.00', top: 20),
      ];
      final result = parseReceiptLines(lines);
      expect(result.amount, 10.00);
    });

    test('falls back to the largest amount when no total-keyword line exists', () {
      final lines = [
        _line('Item A \$5.00', top: 0),
        _line('Item B \$12.99', top: 20),
      ];
      final result = parseReceiptLines(lines);
      expect(result.amount, 12.99);
    });

    test('returns null amount when no currency-shaped number is found', () {
      final lines = [_line('Corner Market'), _line('Thank you for shopping')];
      final result = parseReceiptLines(lines);
      expect(result.amount, isNull);
    });

    test('redacts a long digit run before it can appear as the merchant guess', () {
      final lines = [_line('Card 411111111111'), _line('Total \$20.00', top: 20)];
      final result = parseReceiptLines(lines);
      expect(result.merchant, contains('••••'));
      expect(result.merchant, isNot(contains('411111111111')));
    });

    test('parses an ISO-format date (YYYY-MM-DD)', () {
      final lines = [_line('2026-03-05')];
      final result = parseReceiptLines(lines);
      expect(result.occurredAt, DateTime(2026, 3, 5));
    });
  });
}
