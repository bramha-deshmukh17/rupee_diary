import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../model/transactions.dart'; // make sure this model exists

class TransactionsDao {
  final Database database;
  TransactionsDao(this.database);

  // TABLE CREATION
  static const createTable = '''
    CREATE TABLE transactions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bank_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      type TEXT NOT NULL,             -- credit / debit
      date DATETIME NOT NULL,
      category INTEGER,
      notes TEXT,
      FOREIGN KEY (bank_id) REFERENCES bank(id)
    );
  ''';

  // 🔹 INSERT ONLY (No update / delete)
  Future<int> insertTransaction(Map<String, dynamic> data) async {
    return await database.insert('transactions', data);
  }

  // 🔹 GET ALL
  Future<List<TransactionModel>> getAll() async {
    final rows = await database.query('transactions', orderBy: 'date DESC');
    return rows.map(TransactionModel.fromMap).toList();
  }


  // ===========================
  // DEBUG: PARSED MODELS
  Future<void> debugPrintAllModels() async {
    final list = await getAll();
    debugPrint('💳 ===== TRANSACTIONS (MODELS) =====');
    if (list.isEmpty) {
      debugPrint('⚠️ No transactions found');
    } else {
      for (final t in list) {
        debugPrint(
          '🧾 ID: ${t.id} | BANK: ${t.bankId} | ${t.type.toUpperCase()} | ₹${t.amount} '
          '| DATE: ${t.date.toIso8601String()} | CATEGORY: ${t.category} | NOTES: ${t.notes}',
        );
      }
    }
    debugPrint('💳 ===== END =====');
  }
}
