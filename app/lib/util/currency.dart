/// Shared currency formatter — every screen that shows a dollar amount
/// must import this instead of hand-rolling `toStringAsFixed(2)`, so
/// thousands separators and the sign are consistent everywhere.
///
/// The sign is applied to the whole formatted string (`-$1,234.56`), not
/// swept into the thousands-separator loop — grouping runs on the
/// absolute value only.
String formatCurrency(double amount) {
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
  return isNegative ? '-\$$formatted' : '\$$formatted';
}
