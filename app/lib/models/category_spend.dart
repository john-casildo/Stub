import 'package:flutter/material.dart';

class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.name,
    required this.fraction,
    required this.color,
    required this.icon,
  });

  final String categoryId;
  final String name;
  /// Fraction (0.0-1.2, matching `BudgetLimit.fraction`) of this
  /// category's budget limit spent so far this period — null when the
  /// category has no budget at all, so there's nothing to show a
  /// percentage of.
  final double? fraction;
  final Color color;
  /// Key into lib/theme/category_icons.dart's curated icon set.
  final String icon;
}
