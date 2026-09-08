import '../data/text_recognition_service.dart';
import '../models/transaction.dart';

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
// Receipts and bank screenshots print a genuine grand-total line — Spanish
// and English share the word "total", so only the "amount due"/"a pagar"
// variants need a bilingual alternative.
final _receiptTotalKeywordPattern = RegExp(r'total|amount due|a pagar', caseSensitive: false);
// Payment-app confirmation screens (SINPE Móvil, Venmo-style transfers)
// often skip the word "total" altogether in favor of a generic amount
// label or a sent/paid verb — broader on purpose since the exact wording
// varies a lot between apps.
final _paymentAppKeywordPattern = RegExp(
  r'total|monto|amount|enviad[oa]|enviaste|pagad[oa]|pagaste|sent|paid',
  caseSensitive: false,
);
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

/// Row-clusters [lines] by vertical position, sorting each row
/// left-to-right — the OCR spike's validated technique for correcting
/// out-of-order reads on receipts with multi-column layouts. Returns the
/// rows themselves (not a flattened list) so callers can choose whether
/// to treat each row as one joined unit (needed for label+amount
/// detection — see [parseReceiptLines]) or iterate line-by-line.
List<List<RecognizedLine>> _reconstructRows(List<RecognizedLine> lines) {
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
  return rows;
}

/// Rejects month/day combinations no calendar has — guards against, e.g.,
/// a receipt reference number like "13-2-1520258" matching the
/// MM-DD-YYYY shape (month "13" isn't real; `DateTime` would otherwise
/// silently roll it over into January of the following year rather than
/// throwing, producing a garbage date instead of an error).
bool _isPlausibleDate(int month, int day) => month >= 1 && month <= 12 && day >= 1 && day <= 31;

DateTime? _parseDate(String text) {
  // Check ISO format first (more specific — requires 4-digit year at start)
  final iso = _isoDatePattern.firstMatch(text);
  if (iso != null) {
    final month = int.parse(iso.group(2)!);
    final day = int.parse(iso.group(3)!);
    if (_isPlausibleDate(month, day)) {
      return DateTime(int.parse(iso.group(1)!), month, day);
    }
  }
  // Fall back to MM/DD/YYYY or MM-DD-YYYY format
  final mmddyyyy = _mmddyyyyPattern.firstMatch(text);
  if (mmddyyyy != null) {
    final month = int.parse(mmddyyyy.group(1)!);
    final day = int.parse(mmddyyyy.group(2)!);
    if (_isPlausibleDate(month, day)) {
      var year = int.parse(mmddyyyy.group(3)!);
      if (year < 100) year += 2000;
      return DateTime(year, month, day);
    }
  }
  return null;
}

/// Case-insensitive normalized edit-distance similarity, 0 (nothing alike)
/// to 1 (identical) — used to correct a merchant line's OCR noise against
/// names already seen in past transactions (see [parseReceiptLines]).
double _similarity(String a, String b) {
  final normA = a.toLowerCase();
  final normB = b.toLowerCase();
  final maxLen = normA.length > normB.length ? normA.length : normB.length;
  if (maxLen == 0) return 1.0;
  return 1 - (_levenshtein(normA, normB) / maxLen);
}

int _levenshtein(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previousRow = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final currentRow = List<int>.filled(b.length + 1, 0);
    currentRow[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      currentRow[j] = [
        previousRow[j] + 1, // deletion
        currentRow[j - 1] + 1, // insertion
        previousRow[j - 1] + cost, // substitution
      ].reduce((x, y) => x < y ? x : y);
    }
    previousRow = currentRow;
  }
  return previousRow[b.length];
}

/// A candidate line must be at least this similar to a known merchant
/// name to be corrected to it — lenient enough to absorb typical OCR
/// character-level noise, strict enough not to misfire between two
/// genuinely different merchant names.
const _merchantMatchThreshold = 0.5;

/// Only lines near the top of the receipt are considered for known-
/// merchant matching — a coincidental resemblance to an interior line
/// (an item name, an address) shouldn't override the real header.
const _merchantMatchLineLimit = 5;

/// Extracts a best-effort merchant/amount/date guess from OCR output.
/// Every field may come back null — the caller must always route the
/// result through a review screen, never save it directly.
///
/// [knownMerchants] (typically merchant names from past transactions)
/// lets a noisy OCR read of the header be corrected to a name the user
/// has already used, rather than saving fresh garbage each time the same
/// store is scanned — falls back to the raw first line when nothing
/// matches closely enough.
///
/// [source] selects which bilingual (English/Spanish) keyword set is used
/// to find the total-style amount: receipts and bank screenshots print a
/// genuine "total", while payment-app confirmations often use a generic
/// amount label or a sent/paid verb instead — see
/// `_receiptTotalKeywordPattern`/`_paymentAppKeywordPattern`. Defaults to
/// the receipt keyword set.
ParsedReceipt parseReceiptLines(
  List<RecognizedLine> lines, {
  List<String> knownMerchants = const [],
  TransactionSource source = TransactionSource.receipt,
}) {
  final totalKeywordPattern =
      source == TransactionSource.paymentApp ? _paymentAppKeywordPattern : _receiptTotalKeywordPattern;
  final rows = _reconstructRows(lines);
  final ordered = [for (final row in rows) ...row];
  final redactedTexts = [for (final l in ordered) redactLongDigitRuns(l.text)];
  // A label ("TOTAL:") and its amount are often OCR'd as two separate
  // text blocks even when they sit on the same printed row (a wide gap
  // between a left-aligned label and a right-aligned number is enough to
  // split them) — joining each row into one string before searching for
  // the total keyword is what lets "TOTAL:" + "5,415.00" match together,
  // rather than neither half matching and the parser silently falling
  // back to the largest number anywhere on the receipt (often the cash
  // tendered, not the total).
  final rowTexts = [
    for (final row in rows) row.map((l) => redactLongDigitRuns(l.text)).join(' '),
  ];

  double? largestAmount;
  double? totalLineAmount;
  for (final text in rowTexts) {
    final match = _amountPattern.firstMatch(text);
    if (match == null) continue;
    final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (value == null) continue;
    if (largestAmount == null || value > largestAmount) largestAmount = value;
    if (totalKeywordPattern.hasMatch(text)) {
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
  String? bestKnownMatch;
  var bestScore = _merchantMatchThreshold;
  var candidatesChecked = 0;
  for (final text in redactedTexts) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) continue;
    merchant ??= trimmed;
    if (candidatesChecked >= _merchantMatchLineLimit) continue;
    candidatesChecked++;
    for (final known in knownMerchants) {
      final score = _similarity(trimmed, known);
      if (score > bestScore) {
        bestScore = score;
        bestKnownMatch = known;
      }
    }
  }
  if (bestKnownMatch != null) merchant = bestKnownMatch;

  return ParsedReceipt(
    merchant: merchant,
    amount: totalLineAmount ?? largestAmount,
    occurredAt: occurredAt,
  );
}
