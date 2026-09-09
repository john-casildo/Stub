class Category {
  const Category({
    required this.id,
    required this.name,
    this.currencyCode,
    this.icon = 'tag',
    this.colorIndex,
  });

  final String id;
  final String name;
  /// Overrides the app's global default currency for this category's
  /// amounts (e.g. a category tracked in Costa Rican colones while
  /// everything else defaults to dollars). Null means "use the default".
  final String? currencyCode;
  /// Key into lib/theme/category_icons.dart's curated icon set, chosen at
  /// creation. Defaults to the generic 'tag' icon.
  final String icon;
  /// Index into lib/theme/category_colors.dart's 6-slot swatch palette,
  /// chosen at creation. Null only for a category created before color
  /// picking existed — see categoryColorIndexFor's fallback.
  final int? colorIndex;

  factory Category.fromRow(Map<String, dynamic> row) => Category(
        id: row['id'] as String,
        name: row['name'] as String,
        currencyCode: row['currency_code'] as String?,
        icon: row['icon'] as String? ?? 'tag',
        colorIndex: row['color_index'] as int?,
      );

  Map<String, dynamic> toInsertRow(String userId) => {
        'user_id': userId,
        'name': name,
        'currency_code': currencyCode,
        'icon': icon,
        'color_index': colorIndex,
      };
}
