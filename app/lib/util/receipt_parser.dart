import '../data/text_recognition_service.dart';

/// Best-effort merchant/amount/date guesses extracted from OCR output —
/// any field may be null if nothing confident was found. Always routed
/// through a mandatory human-review screen (`EditEntryScreen`) before
/// being saved, per the OCR spike's findings (see CLAUDE.md) — never
/// auto-saved.
class ParsedReceipt {
  const ParsedReceipt({this.merchant, this.amount, this.occurredAt});

  final String? merchant;
  final double? amount;
  final DateTime? occurredAt;
}

final _amountPattern = RegExp(r'\$?\s?(\d{1,3}(?:,\d{3})*\.\d{2})');
final _totalKeywordPattern = RegExp(r'total|amount due', caseSensitive: false);
final _mmddyyyyPattern = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');
final _isoDatePattern = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
final _longDigitRunPattern = RegExp(r'\d{8,}');

/// Masks any run of 8+ consecutive digits (account/ID numbers), keeping
/// only the last 4 — applied unconditionally before any extraction below
/// so a raw account number can never survive into a stored transaction
/// or the UI, regardless of which heuristic produced the match.
String redactLongDigitRuns(String text) {
  return text.replaceAllMapped(_longDigitRunPattern, (match) {
    final digits = match.group(0)!;
    return '••••${digits.substring(digits.length - 4)}';
  });
}

/// Row-clusters [lines] by vertical position, then sorts each row
/// left-to-right — the OCR spike's validated technique for correcting
/// out-of-order reads on receipts with multi-column layouts.
List<RecognizedLine> _reconstructReadingOrder(List<RecognizedLine> lines) {
  if (lines.isEmpty) return const [];
  final sorted = [...lines]..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
  final rows = <List<RecognizedLine>>[];
  for (final line in sorted) {
    final lineHeight = line.boundingBox.height;
    List<RecognizedLine>? matchingRow;
    for (final row in rows) {
      final rowTop = row.first.boundingBox.top;
      if ((line.boundingBox.top - rowTop).abs() < lineHeight * 0.6) {
        matchingRow = row;
        break;
      }
    }
    if (matchingRow != null) {
      matchingRow.add(line);
    } else {
      rows.add([line]);
    }
  }
  for (final row in rows) {
    row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
  }
  final result = <RecognizedLine>[];
  for (final row in rows) {
    result.addAll(row);
  }
  return result;
}

DateTime? _parseDate(String text) {
  // Check ISO format first (more specific — requires 4-digit year at start)
  final iso = _isoDatePattern.firstMatch(text);
  if (iso != null) {
    return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
  }
  // Fall back to MM/DD/YYYY or MM-DD-YYYY format
  final mmddyyyy = _mmddyyyyPattern.firstMatch(text);
  if (mmddyyyy != null) {
    final month = int.parse(mmddyyyy.group(1)!);
    final day = int.parse(mmddyyyy.group(2)!);
    var year = int.parse(mmddyyyy.group(3)!);
    if (year < 100) year += 2000;
    return DateTime(year, month, day);
  }
  return null;
}

/// Extracts a best-effort merchant/amount/date guess from OCR output.
/// Every field may come back null — the caller must always route the
/// result through a review screen, never save it directly.
ParsedReceipt parseReceiptLines(List<RecognizedLine> lines) {
  final ordered = _reconstructReadingOrder(lines);
  final redactedTexts = [for (final l in ordered) redactLongDigitRuns(l.text)];

  double? largestAmount;
  double? totalLineAmount;
  for (final text in redactedTexts) {
    final match = _amountPattern.firstMatch(text);
    if (match == null) continue;
    final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (value == null) continue;
    if (largestAmount == null || value > largestAmount) largestAmount = value;
    if (_totalKeywordPattern.hasMatch(text)) {
      // A grand total is always >= any subtotal/tax line by construction,
      // so taking the largest among total-keyword matches (rather than the
      // first) avoids "Subtotal" — which contains the substring "total" —
      // winning over the real "Total" line.
      if (totalLineAmount == null || value > totalLineAmount) {
        totalLineAmount = value;
      }
    }
  }

  DateTime? occurredAt;
  for (final text in redactedTexts) {
    occurredAt = _parseDate(text);
    if (occurredAt != null) break;
  }

  String? merchant;
  for (final text in redactedTexts) {
    if (text.trim().isNotEmpty) {
      merchant = text;
      break;
    }
  }

  return ParsedReceipt(
    merchant: merchant,
    amount: totalLineAmount ?? largestAmount,
    occurredAt: occurredAt,
  );
}
