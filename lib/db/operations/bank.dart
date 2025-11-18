import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../model/bank.dart';

class BankDao {
  final Database database;
  BankDao(this.database);

  static const createTable = '''
      create table bank(
        id integer primary key autoincrement,
        name text not null,
        balance real not null,
      );
  ''';


  Future<int> insertBank(Bank bank) {
    return database.insert('bank', bank.toMap());
  }

  Future<List<Bank>> getBanks() async {
    final rows = await database.query('bank', orderBy: 'name ASC');
    return rows.map((e) => Bank.fromMap(e)).toList();
  }

  Future<int> updateBank(Bank bank) {
    if (bank.id == null) {
      throw ArgumentError('Bank id required for update');
    }
    return database.update(
      'bank',
      bank.toMap(),
      where: 'id = ?',
      whereArgs: [bank.id],
    );
  }

  Future<int> deleteBank(Bank bank) {
     if (bank.id == null) {
      throw ArgumentError('Bank id required for update');
    }
    return database.delete(
      'bank',
      where: 'id = ?',
      whereArgs: [bank.id],
    );
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
