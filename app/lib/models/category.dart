class Category {
  const Category({required this.id, required this.name});

  final String id;
  final String name;

  factory Category.fromRow(Map<String, dynamic> row) =>
      Category(id: row['id'] as String, name: row['name'] as String);

  Map<String, dynamic> toInsertRow(String userId) => {'user_id': userId, 'name': name};
}
