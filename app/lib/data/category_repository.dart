import '../models/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> list();
  Future<Category> create(String name, {String? currencyCode, String icon = 'tag', int? colorIndex});
  Future<void> delete(String id);
}
