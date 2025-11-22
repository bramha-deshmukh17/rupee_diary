import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../model/bank.dart';

class BankDao {
  final Database database;
  BankDao(this.database);

  static const createTable = '''
    CREATE TABLE IF NOT EXISTS bank(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      balance REAL NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 0
    );
  ''';

  Future<int> insertBank(Bank bank) async {
    // If no default exists, make this one default automatically.
    final existingDefault = await database.query(
      'bank',
      where: 'is_default = 1',
      limit: 1,
    );
    final makeDefault = existingDefault.isEmpty;
    return database.insert(
      'bank',
      bank.copyWith(isDefault: makeDefault).toMap(),
    );
  }

  Future<List<Bank>> getBanks() async {
    final rows = await database.query('bank', orderBy: 'name ASC');
    return rows.map((e) => Bank.fromMap(e)).toList();
  }

   Future<int> updateBank(int id, double delta) {
    return database.rawUpdate(
      'UPDATE bank SET balance = balance + ? WHERE id = ?',
      [delta, id],
    );
  }

  Future<int> deleteBank(Bank bank) {
    if (bank.id == null) {
      throw ArgumentError('Bank id required for update');
    }
    return database.delete('bank', where: 'id = ? and is_default = ?', whereArgs: [bank.id, 0]);
  }

  Future<void> setDefault(int id) async {
    await database.transaction((txn) async {
      await txn.update('bank', {'is_default': 0});
      await txn.update(
        'bank',
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<Bank?> getDefaultBank() async {
    final rows = await database.query(
      'bank',
      where: 'is_default = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Bank.fromMap(rows.first);
  }

  // ===========================
  // DEBUG: PARSED BANK MODELS
  Future<void> debugPrintAllModels() async {
    final list = await getBanks();
    debugPrint('🏦 ===== BANK TABLE (MODELS) =====');
    if (list.isEmpty) {
      debugPrint('⚠️ No bank records found');
    } else {
      for (final b in list) {
        debugPrint('💰 ID: ${b.id} | NAME: ${b.name} | BALANCE: ₹${b.balance}');
      }
    }
    debugPrint('🏦 ===== END =====');
  }
}
