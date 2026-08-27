import 'package:supabase_flutter/supabase_flutter.dart';
import 'category_repository.dart';
import '../models/category.dart';

class SupabaseCategoryRepository implements CategoryRepository {
  SupabaseCategoryRepository(this._client);
  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Category>> list() async {
    final rows = await _client.from('categories').select().order('created_at');
    return rows.map((row) => Category.fromRow(row)).toList();
  }

  @override
  Future<Category> create(String name) async {
    final row = await _client.from('categories').insert({'user_id': _userId, 'name': name}).select().single();
    return Category.fromRow(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }
}
