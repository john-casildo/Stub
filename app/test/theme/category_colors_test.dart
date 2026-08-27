import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/theme/category_colors.dart';

void main() {
  test('categoryColor cycles deterministically through the palette', () {
    final first = categoryColor(0, Brightness.light);
    final seventh = categoryColor(6, Brightness.light); // wraps back to index 0
    expect(first, seventh);
    expect(categoryColor(0, Brightness.light), isNot(categoryColor(1, Brightness.light)));
    expect(categoryColor(0, Brightness.light), isNot(categoryColor(0, Brightness.dark)));
  });
}
