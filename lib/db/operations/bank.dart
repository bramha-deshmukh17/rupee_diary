import 'package:sqflite/sqflite.dart';

import '../model/bank.dart';

class BankDao {
  final Database database;
  BankDao(this.database);

  //create query
  static const createTable = '''
    create table bank(
      id integer primary key autoincrement,
      name text not null,
      balance real not null,
      isDefault integer not null default 0
    );
  ''';

  //insert into bank table
  Future<int> insertBank(BankModel bank) async {
    // If no default exists, make this one default automatically, inside a transaction.
    final id = await database.transaction<int>((txn) async {
      final existingDefault = await txn.query(
        'bank',
        where: 'isDefault = 1',
        limit: 1,
      );
      final makeDefault = existingDefault.isEmpty;
      return await txn.insert(
        'bank',
        bank.copyWith(isDefault: makeDefault).toMap(),
      );
    });
    return id;
  }

  //get all banks
  Future<List<BankModel>> getBanks() async {
    final rows = await database.query('bank', orderBy: 'name ASC');
    return rows.map((e) => BankModel.fromMap(e)).toList();
  }

  //delete bank by id
  Future<int> deleteBank(BankModel bank) {
    if (bank.id == null) {
      throw ArgumentError('Bank id required for update');
    }
    return database.delete(
      'bank',
      where: 'id = ? and isDefault = ?',
      whereArgs: [bank.id, 0],
    );
  }

  //set default bank by id
  Future<void> setDefault(int id) async {
    await database.transaction((txn) async {
      await txn.update('bank', {'isDefault': 0});
      await txn.update(
        'bank',
        {'isDefault': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
