import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

import '../model/bank.dart';
import '../model/transactions.dart';

class TransactionsDao {
  final Database database;
  TransactionsDao(this.database);

  // TABLE CREATION
  static const createTable = '''
    create table if not exists transactions(
      id integer primary key autoincrement,
      bankId integer not null,
      amount real not null,
      type text not null,
      balance real not null,
      categoryId integer,
      date text not null,
      notes text,
      foreign key (bankId) references bank(id) on delete cascade,
      foreign key (categoryId) references categories(id) on delete set null
    );
  ''';

  // insert transaction and update bank balance atomically
  Future<int> insertTransaction(Map<String, dynamic> t) async {
    return await database.transaction((txn) async {
      final int bankId = (t['bankId'] ?? t['bank_id']) as int;
      final double amount = (t['amount'] as num).toDouble();
      final String type = (t['type'] as String).toLowerCase();
      final String dateIso =
          (t['date'] as String?) ?? DateTime.now().toIso8601String();
      final String? notes = t['notes']?.toString();

      int? categoryId = t['categoryId'] as int?;

      final bankRows = await txn.query(
        'bank',
        columns: ['balance'],
        where: 'id = ?',
        whereArgs: [bankId],
        limit: 1,
      );
      if (bankRows.isEmpty) throw Exception('bank not found');

      final currentBalance =
          (bankRows.first['balance'] as num?)?.toDouble() ?? 0.0;

      final delta = (type == 'income' || type == 'borrow') ? amount : -amount;
      final newBalance = currentBalance + delta;

      final nBank = await txn.rawUpdate(
        'update bank set balance = ? where id = ?',
        [newBalance, bankId],
      );
      if (nBank == 0) throw Exception('failed to update bank balance');

      return await txn.insert('transactions', {
        'bankId': bankId,
        'amount': amount,
        'balance': newBalance,
        'type': type,
        'categoryId': categoryId,
        'date': dateIso,
        'notes': notes,
      });
    });
  }

  //  check transactions exist for a bank
  Future<bool> getTransactionByBankId(BankModel b) async {
    final rows = await database.query(
      'transactions',
      where: 'bankId = ?',
      whereArgs: [b.id!],
    );
    return rows.isNotEmpty;
  }

  //get list of all transactions to show on the history page
  //with pagination (limit, offset)
  Future<List<TransactionModel>> getAll(int limit, int offset) async {
    final rows = await database.rawQuery(
      '''
      select
        t.id,
        b.name as bankName,
        t.amount,
        t.balance,
        t.type,
        t.categoryId,
        c.name as category,
        c.icon_code_point,
        c.icon_font_family,
        c.icon_font_package,
        t.date,
        t.notes
      from transactions t
      join bank b on t.bankId = b.id
      left join categories c on t.categoryId = c.id
      order by datetime(t.date) desc
      limit ? offset ?
      ''',
      [limit, offset],
    );

    return rows.map((e) => TransactionModel.fromMap(e)).toList();
  }

  // get filtered transactions with different paramerters from the user
  Future<List<TransactionModel>> getFiltered({
    required int limit,
    required int offset,
    int? bankId,
    String? type,
    int? categoryId,
    DateTime? from,
    DateTime? to,
    double? minAmount,
    double? maxAmount,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (bankId != null) {
      where.add('t.bankId = ?');
      args.add(bankId);
    }
    if (type != null) {
      where.add('t.type = ?');
      args.add(type);
    }
    if (categoryId != null) {
      where.add('cast(categoryId as integer) = ?');
      args.add(categoryId);
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
      select
        t.id,
        t.bankId,
        b.name as bankName,
        t.amount,
        t.balance,
        t.type,
        t.categoryId,
        c.name as category,
        c.icon_code_point,
        c.icon_font_family,
        c.icon_font_package,
        t.date,
        t.notes
      from transactions t
      join bank b on t.bankId = b.id
      left join categories c on t.categoryId = c.id
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
        select coalesce(sum(amount), 0) as totalIncome
        from transactions
        where type = 'income'
          and date(date) >= date('now', 'start of month', 'localtime')
          and date(date) <= date('now', 'localtime')
      ''');

      expenseResult = await txn.rawQuery('''
        select coalesce(sum(amount), 0) as totalExpense
        from transactions
        where type = 'expense'
          and date(date) >= date('now', 'start of month', 'localtime')
          and date(date) <= date('now', 'localtime')
      ''');

      balanceResult = await txn.rawQuery('''
        select coalesce(sum(balance), 0) as totalBalance
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

    final totalIncome = toDouble(incomeResult.first['totalIncome']);
    final totalExpense = toDouble(expenseResult.first['totalExpense']);
    final totalBalance = toDouble(balanceResult.first['totalBalance']);
    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'totalBalance': totalBalance,
    };
  }

  //here weare taking last 5 transaction to show on the home page
  Future<List<TransactionModel>> getRecentTransactions() async {
    final rows = await database.rawQuery(
      ''' 
      select
        t.id,
        b.name as bankName,
        t.amount,
        t.balance,
        t.type,
        t.categoryId,
        c.name as category,
        c.icon_code_point,
        c.icon_font_family,
        c.icon_font_package,
        t.date,
        t.notes
      from transactions t
      join bank b on t.bankId = b.id
      left join categories c on t.categoryId = c.id
      order by datetime(t.date) desc
      limit ?
      ''',
      [5],
    );
    return rows.map((e) => TransactionModel.fromMap(e)).toList();
  }

  Future<List<Map<int, double?>>> getCategoryExpense() async {
    final rows = await database.rawQuery('''
      select categoryId, sum(amount) as totalAmount
      from transactions
      where type = 'expense' and categoryId is not null
      group by categoryId
      ''');

    final List<Map<int, double?>> result = [];
    for (final e in rows) {
      final rawId = e['categoryId'];
      if (rawId == null || rawId is! num) continue;

      final id = rawId.toInt();
      final total = (e['totalAmount'] as num?)?.toDouble();
      result.add({id: total});
    }
    return result;
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
          '| DATE: ${t.date.toIso8601String()} | CATEGORY: ${t.categoryId} | NOTES: ${t.notes}',
        );
      }
    }
    debugPrint('💳 ===== END =====');
  }
}
