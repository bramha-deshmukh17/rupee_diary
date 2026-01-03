import 'package:sqflite/sqflite.dart';

import '../model/budget.dart';

class BudgetDao {
  final Database database;
  BudgetDao(this.database);

  static String createTable = '''
    create table budget(
      id integer primary key autoincrement,
      categoryId integer not null,
      year integer not null,
      month integer not null,
      amount real not null,
      unique(categoryId, year, month),
      foreign key (categoryId) references categories(id) on delete cascade
    );
  ''';

  Future<int> insertBudget(BudgetModel budget) async {
    return await database.insert('budget', budget.toMap());
  }

  Future<List<Map<String, dynamic>>> getAllBudgetsOfTheMonth(int year, int month) async {
    final List<Map<String, dynamic>> maps = await database.rawQuery('''
      SELECT b.id, b.amount, c.name as category, c.id as categoryId, c.icon_code_point, c.icon_font_family, c.icon_font_package
      FROM budget b
      JOIN categories c ON b.categoryId = c.id
      WHERE b.year = ? AND b.month = ?
    ''', [year, month]);

    return List.generate(maps.length, (i) {
      return {
        'id': maps[i]['id'] as int,
        'amount': maps[i]['amount'] as double,
        'category': maps[i]['category'] as String,
        'categoryId': maps[i]['categoryId'] as int,
        'icon_code_point': maps[i]['icon_code_point'] as int,
        'icon_font_family': maps[i]['icon_font_family'] as String,
        'icon_font_package': maps[i]['icon_font_package'] as String?,
      };
    });
  }

  Future<bool> updateBudget(int id, double amount) async {
    return await database.update(
              'budget',
              {'amount': amount},
              where: 'id = ?',
              whereArgs: [id],
            ) >
            0
        ? true
        : false;
  }

  Future<bool> deleteBudget(int id) async {
    return await database.delete('budget', where: 'id = ?', whereArgs: [id]) > 0
        ? true
        : false;
  }

  Future<double> getTotalBudgetAmount(int year, int month) async {
    final rows = await database.rawQuery(
      'select coalesce(sum(amount), 0) as totalBudget from budget where year = ? and month = ?',
      [year, month],
    );
    if (rows.isEmpty) return 0.0;
    final v = rows.first['totalBudget'];
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
