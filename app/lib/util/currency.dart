/// Deliberately global, mutable display-currency preference — a plain
/// symbol swap (USD vs. CRC), no real conversion between currencies and
/// no per-transaction currency tracking. Kept as simple global state
/// instead of threading a parameter through every `formatCurrency` call
/// site (there are many); the rebuild that actually picks up a change is
/// triggered separately, by the `currencyNotifier` `ValueListenableBuilder`
/// wrapping the whole app in `main.dart` (same pattern as `themeModeNotifier`)
/// — this field only needs to hold the current value by the time that
/// rebuild runs.
class CurrencyConfig {
  CurrencyConfig._();
  static String code = 'USD';
}

/// Symbol for every currency selectable in the app — [supportedCurrencies]
/// is this map's key list, so the two can never drift apart.
const _symbols = <String, String>{
  'USD': '\$',
  'CRC': '₡',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'CNY': '¥',
  'INR': '₹',
  'KRW': '₩',
  'VND': '₫',
  'ILS': '₪',
  'TRY': '₺',
  'PHP': '₱',
  'THB': '฿',
  'UAH': '₴',
  'PLN': 'zł',
  'RUB': '₽',
  'MXN': 'MX\$',
  'BRL': 'R\$',
  'ARS': 'AR\$',
  'CLP': 'CL\$',
  'COP': 'CO\$',
  'CAD': 'CA\$',
  'AUD': 'A\$',
  'NZD': 'NZ\$',
  'HKD': 'HK\$',
  'SGD': 'S\$',
  'CHF': 'CHF',
  'SEK': 'kr',
  'NOK': 'kr',
  'DKK': 'kr',
  'ZAR': 'R',
  'NGN': '₦',
  'EGP': 'E£',
  'AED': 'AED',
  'SAR': 'SAR',
  'PKR': '₨',
  'BDT': '৳',
  'IDR': 'Rp',
  'MYR': 'RM',
  'PEN': 'S/',
};

/// Every currency code selectable across the app (`SettingsScreen`'s
/// global default, `AddCategoryScreen`'s per-category override) — a
/// curated, common-currency subset of ISO 4217, not the full standard.
final List<String> supportedCurrencies = _symbols.keys.toList(growable: false);

String _symbolFor(String code) => _symbols[code] ?? '\$';

/// Shared currency formatter — every screen that shows a dollar amount
/// must import this instead of hand-rolling `toStringAsFixed(2)`, so
/// thousands separators and the sign are consistent everywhere.
///
/// [currencyCode], when given (e.g. a category's own currency override),
/// takes precedence over the global `CurrencyConfig.code` default for
/// just this call.
///
/// The sign is applied to the whole formatted string (`-$1,234.56`), not
/// swept into the thousands-separator loop — grouping runs on the
/// absolute value only.
String formatCurrency(double amount, {String? currencyCode}) {
  final isNegative = amount.isNegative;
  final fixed = amount.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    if (i > 0 && remaining % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  final formatted = '${buffer.toString()}.${parts[1]}';
  final symbol = _symbolFor(currencyCode ?? CurrencyConfig.code);
  return isNegative ? '-$symbol$formatted' : '$symbol$formatted';
}
