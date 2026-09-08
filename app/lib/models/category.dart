class Category {
  const Category({required this.id, required this.name, this.currencyCode});

  final String id;
  final String name;
  /// Overrides the app's global default currency for this category's
  /// amounts (e.g. a category tracked in Costa Rican colones while
  /// everything else defaults to dollars). Null means "use the default".
  final String? currencyCode;

  factory Category.fromRow(Map<String, dynamic> row) => Category(
        id: row['id'] as String,
        name: row['name'] as String,
        currencyCode: row['currency_code'] as String?,
      );

  Map<String, dynamic> toInsertRow(String userId) =>
      {'user_id': userId, 'name': name, 'currency_code': currencyCode};
}
