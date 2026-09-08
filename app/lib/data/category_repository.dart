import '../models/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> list();
  Future<Category> create(String name, {String? currencyCode});
  Future<void> delete(String id);
}
