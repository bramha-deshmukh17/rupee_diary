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
      id integer primary key autoincrement,
      bank_id integer not null,
      amount real not null,
      type text not null,             -- credit / debit
      balance real not null,
      category text,
      date datetime not null,
      notes text,
      foreign key (bank_id) references bank(id) on delete cascade
    );
  ''';

  // insert transaction and update bank balance atomically
  Future<int> insertTransaction(Map<String, dynamic> t) async {
    return await database.transaction((txn) async {
      // normalize inputs
      final int bankId = (t['bank_id'] ?? t['bankId']) as int;
      final double amount = (t['amount'] as num).toDouble();
      final String type = (t['type'] as String).toLowerCase();
      final String category =
          (t['category'] as String?) ?? 'Settlement';
      final String dateIso =
          (t['date'] as String?) ?? DateTime.now().toIso8601String();
      final String? notes = t['notes']?.toString();

      // fetch current bank balance
      final bankRows = await txn.query(
        'bank',
        columns: ['balance'],
        where: 'id = ?',
        whereArgs: [bankId],
      );
      if (bankRows.isEmpty) throw Exception('bank not found');
      final double currentBalance =
          (bankRows.first['balance'] as num?)?.toDouble() ?? 0.0;

      // compute delta
      final double delta =
          (type == 'income' || type == 'borrow') ? amount : -amount;
      final double newBalance = currentBalance + delta;

      // update bank
      final nBank = await txn.rawUpdate(
        'update bank set balance = ? where id = ?',
        [newBalance, bankId],
      );
      if (nBank == 0) {
        debugPrint('failed to update bank balance for bank_id=$bankId');
        throw Exception('failed to update bank balance');
      }

      // insert transaction with computed balance snapshot
      final id = await txn.insert('transactions', {
        'bank_id': bankId,
        'amount': amount,
        'type': type,
        'balance': newBalance,
        'category': category,
        'date': dateIso,
        'notes': notes,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      if (id <= 0) {
        debugPrint(
          'failed to insert transaction for bank_id=$bankId type=$type amount=$amount',
        );
        throw Exception('failed to insert transaction');
      }
      return id;
    });
  }

  //  check transactions exist for a bank
  Future<bool> getTransactionByBankId(Bank b) async {
    final rows = await database.query(
      'transactions',
      where: 'bank_id = ?',
      whereArgs: [b.id!],
    );
    return rows.isNotEmpty;
  }

  //get list of all transactions to show on the history page
  //with pagination (limit, offset)
  Future<List<TransactionModel>> getAll(int limit, int offset) async {
    final data = await database.rawQuery(
      """select t.id, b.name as bankName, t.amount, t.balance, t.type, t.category, t.date, t.notes
          from transactions t
          join bank b on t.bank_id = b.id
          order by t.date DESC
          limit ? offset ?
      """,
      [limit, offset],
    );
    return data.map((e) => TransactionModel.fromMap(e)).toList();
  }

  // get filtered transactions with different paramerters from the user
  Future<List<TransactionModel>> getFiltered({
    required int limit,
    required int offset,
    int? bankId,
    String? type,
    String? category,
    DateTime? from,
    DateTime? to,
    double? minAmount,
    double? maxAmount,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (bankId != null) {
      where.add('t.bank_id = ?');
      args.add(bankId);
    }
    if (type != null) {
      where.add('t.type = ?');
      args.add(type);
    }
    if (category != null) {
      where.add('t.category = ?');
      args.add(category);
    }
    if (from != null) {
      where.add('t.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('t.date <= ?');
      args.add(to.toIso8601String());
    }
    if (minAmount != null) {
      where.add('t.amount >= ?');
      args.add(minAmount);
    }
    if (maxAmount != null) {
      where.add('t.amount <= ?');
      args.add(maxAmount);
    }

    final whereSql = where.isEmpty ? '' : 'where ${where.join(' and ')}';

    final rows = await database.rawQuery(
      '''
      select t.id, t.bank_id, b.name as bankName, t.amount, t.balance, t.type, t.category, t.date, t.notes
      from transactions t
      join bank b on t.bank_id = b.id
      $whereSql
      order by datetime(t.date) desc
      limit ? offset ?
      ''',
      [...args, limit, offset],
    );

    return rows.map((e) => TransactionModel.fromMap(e)).toList();
  }

  //here we are fetching data from db to show on the home page
  //1. total balance in all banks
  //2. total income this month
  //3. total expense this month
  Future<Map<String, double>> getUsage() async {
    late List<Map<String, Object?>> incomeResult;
    late List<Map<String, Object?>> expenseResult;
    late List<Map<String, Object?>> balanceResult;

    await database.transaction((txn) async {
      incomeResult = await txn.rawQuery('''
        select coalesce(sum(amount), 0) as total_income
        from transactions
        where type = 'income'
          and date(date) >= date('now', 'start of month', 'localtime')
          and date(date) <= date('now', 'localtime')
      ''');

      expenseResult = await txn.rawQuery('''
        select coalesce(sum(amount), 0) as total_expense
        from transactions
        where type = 'expense'
          and date(date) >= date('now', 'start of month', 'localtime')
          and date(date) <= date('now', 'localtime')
      ''');

      balanceResult = await txn.rawQuery('''
        select coalesce(sum(balance), 0) as total_balance
        from bank
      ''');
    });

    double toDouble(Object? v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final totalIncome = toDouble(incomeResult.first['total_income']);
    final totalExpense = toDouble(expenseResult.first['total_expense']);
    final totalBalance = toDouble(balanceResult.first['total_balance']);
    return {
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'total_balance': totalBalance,
    };
  }

  //here weare taking last 5 transaction to show on the home page
  Future<List<TransactionModel>> getRecentTransactions() async {
    final rows = await database.rawQuery(
      ''' 
      select t.id, b.name as bankName, t.amount, t.balance, t.type, t.category, t.date, t.notes
      from transactions t
      join bank b on t.bank_id = b.id
      order by datetime(t.date) desc
      limit ?
      ''',
      [5],
    );
    return rows.map((e) => TransactionModel.fromMap(e)).toList();
  }

  // ===========================
  // DEBUG: PARSED MODELS
  Future<void> debugPrintAllModels() async {
    final list = await getAll(1000, 0);
    debugPrint('💳 ===== TRANSACTIONS (MODELS) =====');
    if (list.isEmpty) {
      debugPrint('⚠️ No transactions found');
    } else {
      for (final t in list) {
        debugPrint(
          '🧾 ID: ${t.id} | BANK: ${t.bankName} | ${t.type} | ₹${t.amount} | BALANCE: ${t.balance}'
          '| DATE: ${t.date.toIso8601String()} | CATEGORY: ${t.category} | NOTES: ${t.notes}',
        );
      }
    }
    debugPrint('💳 ===== END =====');
  }
}
