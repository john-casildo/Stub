import 'api_client.dart';
import 'category_repository.dart';
import '../models/category.dart';

class HttpCategoryRepository implements CategoryRepository {
  HttpCategoryRepository(this._client);
  final ApiClient _client;

  @override
  Future<List<Category>> list() async {
    final rows = await _client.getList('/categories');
    return rows.map((row) => Category.fromRow(row as Map<String, dynamic>)).toList();
  }

  @override
  Future<Category> create(String name, {String? currencyCode, String icon = 'tag', int? colorIndex}) async {
    final row = await _client.post('/categories', {
      'name': name,
      'currencyCode': currencyCode,
      'icon': icon,
      'colorIndex': colorIndex,
    });
    return Category.fromRow(row);
  }

  @override
  Future<void> delete(String id) => _client.delete('/categories/$id');
}
