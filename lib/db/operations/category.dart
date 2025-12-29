import 'package:sqflite/sqflite.dart';

import '../model/category.dart';

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

  static String get insertDefaultCategories => '''
    INSERT INTO categories (
      id,
      name,
      icon_code_point,
      icon_font_family,
      icon_font_package
    ) VALUES
      (1, 'Food', 58091, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (2, 'Fuel', 62767, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (3, 'Transport', 61959, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (4, 'Grocery', 62097, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (5, 'Utilities', 62787, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (6, 'Rent/Mortgage', 61461, 'FontAwesomeRegular', 'font_awesome_flutter'),
      (7, 'Medical', 62569, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (8, 'Education', 61853, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (9, 'Shopping', 62096, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (10, 'Entertainment', 61448, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (11, 'Personal Care', 62907, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (12, 'Insurance', 61746, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (13, 'Phone/Internet', 61931, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (14, 'Subscription', 62307, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (15, 'Loan Payment', 63087, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (16, 'Credit Card', 61597, 'FontAwesomeRegular', 'font_awesome_flutter'),
      (17, 'Clothes', 62803, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (18, 'Travel', 61554, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (19, 'Bills', 62832, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (20, 'Gifts', 61547, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (21, 'Income', 61813, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (22, 'Lend', 58619, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (23, 'Borrow', 58619, 'FontAwesomeSolid', 'font_awesome_flutter'),
      (24, 'Settlement', 62133, 'FontAwesomeRegular', 'font_awesome_flutter'),
      (25, 'Others', 63, 'FontAwesomeSolid', 'font_awesome_flutter');
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

  Future<List<CategoryModel>> getExpenseCategories() async {
    final rows = await database.rawQuery('''
      select * from categories
      where name not in ('Income', 'Lend', 'Borrow', 'Settlement')
    ''');
    return rows.map((e) => CategoryModel.fromMap(e)).toList();
  }

  Future<List<CategoryModel>> getAllCategories() async {
    final rows = await database.query('categories');
    return rows.map((e) => CategoryModel.fromMap(e)).toList();
  }
}
