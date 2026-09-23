// app/test/util/receipt_parser_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/text_recognition_service.dart';
import 'package:stub/models/transaction.dart';
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

    test('prefers "Total" over "Subtotal" even though "Subtotal" contains "total"', () {
      final lines = [
        _line('Subtotal \$40.00', top: 0),
        _line('Tax \$3.20', top: 20),
        _line('Total \$43.20', top: 40),
      ];
      final result = parseReceiptLines(lines);
      expect(result.amount, 43.20);
    });

    test('falls back to the largest amount when no total-keyword line exists', () {
      final lines = [
        _line('Item A \$5.00', top: 0),
        _line('Item B \$12.99', top: 20),
      ];
      final result = parseReceiptLines(lines);
      expect(result.amount, 12.99);
    });

    test('for a receipt scan, ignores a "Monto" line and picks the real Total line', () {
      final lines = [
        _line('Monto \$99.00', top: 0),
        _line('Total \$10.00', top: 20),
      ];
      final result = parseReceiptLines(lines, source: TransactionSource.receipt);
      expect(result.amount, 10.00);
    });

    test('for a payment-app scan, recognizes "Monto" as a total-style keyword too', () {
      final lines = [
        _line('Monto \$99.00', top: 0),
        _line('Total \$10.00', top: 20),
      ];
      final result = parseReceiptLines(lines, source: TransactionSource.paymentApp);
      // Both lines carry a recognized keyword for this source; the larger
      // of the two wins (same "grand total >= subtotal" reasoning already
      // applied within a single source's keyword set).
      expect(result.amount, 99.00);
    });

    test('defaults to receipt-style keywords when no source is given', () {
      final lines = [
        _line('Monto \$99.00', top: 0),
        _line('Total \$10.00', top: 20),
      ];
      final result = parseReceiptLines(lines);
      expect(result.amount, 10.00);
    });

    test('joins a total label and its amount when OCR splits them into separate columns on the same row', () {
      // Common real-world layout: "TOTAL:" and its number are visually on
      // the same printed row but OCR'd as two separate text blocks (a
      // wide gap between the left-aligned label and right-aligned
      // number). A larger, unrelated number (cash tendered) sits on a
      // later row and must not win just because it's numerically bigger.
      final lines = [
        _line('TOTAL:', top: 0, left: 0),
        _line('5,415.00', top: 0, left: 150),
        _line('EFECTIVO', top: 20, left: 0),
        _line('10,000.00', top: 20, left: 150),
      ];
      final result = parseReceiptLines(lines);
      expect(result.amount, 5415.00);
    });

    test('never picks a cash-tendered/change amount as the total, even if OCR merges its row with TOTAL', () {
      // On a real device, tight line spacing on some receipts row-merges
      // "TOTAL:" with the very next printed line ("EFECTIVO") into one
      // OCR'd block, which could otherwise let the larger cash-tendered
      // figure masquerade as the total merely by sorting first in the
      // merged row's text.
      final lines = [
        _line('TOTAL: EFECTIVO', top: 0, left: 0),
        _line('10,000.00', top: 0, left: 100),
        _line('5,415.00', top: 0, left: 200),
      ];
      final result = parseReceiptLines(lines);
      expect(result.amount, isNot(10000.00));
    });

    test('returns null amount when no currency-shaped number is found', () {
      final lines = [_line('Corner Market'), _line('Thank you for shopping')];
      final result = parseReceiptLines(lines);
      expect(result.amount, isNull);
    });

    test('prefers a known merchant name when a line fuzzy-matches it, over the raw first line', () {
      // OCR misread the merchant header ("AUT0 MERC4D0 S.A" instead of
      // "Auto Mercado S.A.") but it's close enough to a merchant already
      // seen in past transactions — use the clean known name instead of
      // propagating the OCR noise into a new transaction.
      final lines = [
        _line('AUT0 MERC4D0 S.A', top: 0),
        _line('Total \$20.00', top: 20),
      ];
      final result = parseReceiptLines(lines, knownMerchants: const ['Auto Mercado S.A.']);
      expect(result.merchant, 'Auto Mercado S.A.');
    });

    test('falls back to the first line when no known merchant is close enough', () {
      final lines = [
        _line('Corner Market', top: 0),
        _line('Total \$20.00', top: 20),
      ];
      final result = parseReceiptLines(lines, knownMerchants: const ['Costco', 'Walmart']);
      expect(result.merchant, 'Corner Market');
    });

    test('skips a too-short/garbage first line and uses the next plausible one as merchant', () {
      final lines = [
        _line('fP', top: 0),
        _line('Corner Market', top: 20),
        _line('Total \$10.00', top: 40),
      ];
      final result = parseReceiptLines(lines);
      expect(result.merchant, 'Corner Market');
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

    test('skips a reference-number line that looks like a date but has an invalid month', () {
      // "REFERENCIA INTERNA: 13-2-1520258" matches the MM-DD-YYYY shape
      // but "13" isn't a real month — must not be accepted as a date
      // (Dart's DateTime would silently roll month 13 over into January
      // of the following year, producing a garbage date).
      final lines = [
        _line('REFERENCIA INTERNA: 13-2-1520258', top: 0),
        _line('06/09/2026', top: 20),
      ];
      final result = parseReceiptLines(lines);
      expect(result.occurredAt, DateTime(2026, 6, 9));
    });
  });
}
