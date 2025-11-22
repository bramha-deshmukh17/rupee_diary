import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../model/bank.dart';
import '../model/transactions.dart';

class TransactionsDao {
  final Database database;
  TransactionsDao(this.database);

  // TABLE CREATION
  static const createTable = '''
    create table transactions(
      id integer PRIMARY KEY AUTOINCREMENT,
      bank_id integer NOT NULL,
      amount real NOT NULL,
      type text NOT NULL,             -- credit / debit
      date datetime NOT NULL,
      category text,
      notes text,
      foreign key (bank_id) references bank(id) on delete cascade
    );
  ''';

  // 🔹 INSERT ONLY
  Future<int> insertTransaction(TransactionModel transaction) async {
    return await database.insert('transactions', transaction.toMap());
  }

  // 🔹 GET ALL
  Future<List<TransactionModel>> getAll() async {
    final rows = await database.query('transactions', orderBy: 'date DESC');
    return rows.map(TransactionModel.fromMap).toList();
  }

  Future<bool> getTransactionByBankId(Bank b) async {
    final rows = await database.query(
      'transactions',
      where: 'bank_id = ?',
      whereArgs: [b.id!],
    );
    return rows.isNotEmpty;
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
