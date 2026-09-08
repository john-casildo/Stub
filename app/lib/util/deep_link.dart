/// A parsed `com.stubapp.stub://log-expense` deep link, handed off by
/// `LogExpenseIntent` (see ios/Runner/LogExpenseIntent.swift) so a
/// Shortcuts automation can pre-fill `ManualEntryScreen` for a one-tap
/// confirm — never a silent save.
class ParsedDeepLink {
  const ParsedDeepLink({this.amount, this.merchant});
  final double? amount;
  final String? merchant;
}

/// Null for anything that isn't a recognized `log-expense` link (e.g. the
/// existing `login-callback` auth link, or an unrelated URI) — callers
/// should just ignore those, not treat them as errors. A malformed or
/// missing `amount` inside a recognized link still returns a
/// [ParsedDeepLink] (with `amount: null`), since the caller falls back to
/// `ManualEntryScreen`'s own default in that case rather than failing.
ParsedDeepLink? parseDeepLink(Uri uri) {
  if (uri.scheme != 'com.stubapp.stub' || uri.host != 'log-expense') return null;
  final amountText = uri.queryParameters['amount'];
  final amount = amountText == null ? null : double.tryParse(amountText);
  final merchant = uri.queryParameters['merchant'];
  return ParsedDeepLink(amount: amount, merchant: (merchant == null || merchant.isEmpty) ? null : merchant);
}
