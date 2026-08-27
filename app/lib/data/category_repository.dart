import '../models/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> list();
  Future<Category> create(String name);
  Future<void> delete(String id);
}
