import 'package:sqflite/sqflite.dart';

class CategoryDao {
  final Database database;
  CategoryDao(this.database);

  static const createTable = '''
    create table if not exists categories (
      id integer primary key autoincrement,
      name text not null unique,
      icon_code_point integer not null,
      icon_font_family text,
      icon_font_package text
    )
  ''';

  Future<int?> getIdByName(String name) async {
    final rows = await database.query(
      'categories',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }
}
