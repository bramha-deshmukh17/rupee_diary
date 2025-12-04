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

  // insert otransaction and update bank balance atomically with transaction
  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    await database.transaction((txn) async {
      int n1 = await txn.insert('transactions', transaction);
      int n2 = await txn
          .rawUpdate('update bank set balance = balance + ? where id = ?', [
            transaction['type'] == 'income' || transaction['type'] == 'borrow'
                ? transaction['amount']
                : -transaction['amount'],
            transaction['bank_Id'],
          ]);
      if (n1 == 0 || n2 == 0) {
        throw Exception('Failed to insert transaction or update bank balance');
      }
    });

    return 1;
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

  //delete transaction of lend and borrow type only to keep expense clean
  Future<void> deleteTxn(int id) async {
    await database.transaction((txn) async {
      // Get the transaction details (only lend/borrow)
      final txnData = await txn.query(
        'transactions',
        where: 'id = ? and type in ("lend", "borrow")',
        whereArgs: [id],
      );
      if (txnData.isEmpty) {
        throw Exception('Transaction not found or not a lend/borrow');
      }
      
      final Map<String, dynamic> transaction = Map.from(txnData.first);

      // Resolve bank id and ensure it's present
      final bankId = transaction['bank_id'];
      if (bankId == null) {
        throw Exception('Missing bank id on transaction');
      }

      // Normalize amount to double
      final amount =
          (transaction['amount'] is num)
              ? (transaction['amount'] as num).toDouble()
              : double.tryParse(transaction['amount'].toString()) ?? 0.0;

      // Compute delta to apply to bank balance (reverse the original effect)
      final type = transaction['type']?.toString();
      final double delta = (type == 'borrow') ? -amount : amount;

      // Delete the transaction and update bank balance atomically
      final n1 = await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );
      final n2 = await txn.rawUpdate(
        'update bank set balance = balance + ? where id = ?',
        [delta, bankId],
      );

      if (n1 == 0 || n2 == 0) {
        throw Exception('Failed to delete transaction or update bank balance');
      }
    });
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
          '🧾 ID: ${t.id} | BANK: ${t.bankName} | ${t.type.toUpperCase()} | ₹${t.amount} | BALANCE: ${t.balance}'
          '| DATE: ${t.date.toIso8601String()} | CATEGORY: ${t.category} | NOTES: ${t.notes}',
        );
      }
    }
    debugPrint('💳 ===== END =====');
  }
}
