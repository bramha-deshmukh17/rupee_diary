import 'package:rupee_diary/statistics/statistics_screen.dart';
import 'package:sqflite/sqflite.dart';
import '../../transactions/history.dart';
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
    TransactionFilter? filter,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (filter?.bankId != null) {
      where.add('t.bankId = ?');
      args.add(filter!.bankId);
    }
    if (filter?.type != null) {
      where.add('t.type = ?');
      args.add(filter!.type);
    }
    if (filter?.categoryId != null) {
      where.add('cast(categoryId as integer) = ?');
      args.add(filter!.categoryId);
    }
    if (filter?.from != null) {
      where.add('t.date >= ?');
      args.add(filter!.from!.toIso8601String());
    }
    if (filter?.to != null) {
      where.add('t.date <= ?');
      args.add(filter!.to!.toIso8601String());
    }
    if (filter?.minAmount != null) {
      where.add('t.amount >= ?');
      args.add(filter!.minAmount);
    }
    if (filter?.maxAmount != null) {
      where.add('t.amount <= ?');
      args.add(filter!.maxAmount);
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

  //here for budget we will fetch transaction data of whole month for all categories
  Future<List<Map<int, double?>>> getCategoryExpense() async {
    final rows = await database.rawQuery('''
      select categoryId, sum(amount) as totalAmount
      from transactions
      where type = 'expense'
        and categoryId is not null
        and date(date) >= date('now', 'start of month', 'localtime')
        and date(date) < date('now', 'start of month', '+1 month', 'localtime')
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

  //top 3 spending category for stats
  Future<List<Map<String, dynamic>>> getTopSpendingCategory() async {
    final rows = await database.rawQuery(''' 
      select 
        sum(t.amount) as totalSpending,
        c.id,
        c.name as category,
        c.icon_code_point,
        c.icon_font_family,
        c.icon_font_package
      from transactions t
      join categories c on t.categoryId = c.id
      where date(t.date) >= date('now', '-30 days', 'localtime')
        and t.type = 'expense'
        and t.categoryId is not null
      group by 
        c.id,
        c.name,
        c.icon_code_point,
        c.icon_font_family,
        c.icon_font_package
      order by totalSpending desc
      limit 3
      ''');
    return rows;
  }

  //fetch statistics data based on filter
  Future<dynamic> getStatistics(StatisticsFilter filter) async {}

  //last 5 month transaction data for stats
  Future<List<Map<String, Object?>>> getLastFiveMonthsExpense() async {
    final rows = await database.rawQuery('''
      select
        date(date, 'start of month', 'localtime') as monthStart,
        sum(amount) as totalExpense
      from transactions
      where type = 'expense'
        and date(date) >= date('now', 'start of month', '-4 months', 'localtime')
      group by monthStart
      order by monthStart
    ''');
    return rows;
  }


  void _applyStatsDateAndBankFilter(
    StatisticsFilter filter,
    List<String> where,
    List<Object?> args, {
    String tableAlias = 't',
  }) {
    // Only date range now.
    // If from & to set -> use that; else -> last 30 days.
    if (filter.from != null && filter.to != null) {
      where.add('$tableAlias.date >= ?');
      where.add('$tableAlias.date <= ?');
      args.add(filter.from!.toIso8601String());
      args.add(filter.to!.toIso8601String());
      return;
    }

    // default: last 30 days
    where.add("date($tableAlias.date) >= date('now', '-30 days', 'localtime')");
  }
  // top 3 spending categories, filtered by date/bank
  Future<List<Map<String, dynamic>>> getTopSpendingCategoryForStats(
    StatisticsFilter filter,
  ) async {
    final where = <String>["t.type = 'expense'", 't.categoryId is not null'];
    final args = <Object?>[];

    _applyStatsDateAndBankFilter(filter, where, args, tableAlias: 't');
    final whereSql = 'where ${where.join(' and ')}';

    final rows = await database.rawQuery('''
      select 
        sum(t.amount) as totalSpending,
        c.id,
        c.name as category,
        c.icon_code_point,
        c.icon_font_family,
        c.icon_font_package
      from transactions t
      join categories c on t.categoryId = c.id
      $whereSql
      group by 
        c.id,
        c.name,
        c.icon_code_point,
        c.icon_font_family,
        c.icon_font_package
      order by totalSpending desc
      limit 3
      ''', args);
    return rows;
  }

  // category-wise expense for pie chart, filtered by date/bank
  Future<List<Map<String, dynamic>>> getCategoryExpenseForStats(
    StatisticsFilter filter,
  ) async {
    final where = <String>["t.type = 'expense'", 't.categoryId is not null'];
    final args = <Object?>[];

    _applyStatsDateAndBankFilter(filter, where, args, tableAlias: 't');
    final whereSql = 'where ${where.join(' and ')}';

    final rows = await database.rawQuery('''
      select 
        c.id,
        c.name as category,
        c.icon_code_point,
        c.icon_font_family,
        c.icon_font_package,
        sum(t.amount) as totalExpense
      from transactions t
      join categories c on t.categoryId = c.id
      $whereSql
      group by 
        c.id,
        c.name,
        c.icon_code_point,
        c.icon_font_family,
        c.icon_font_package
      order by totalExpense desc
      ''', args);
    return rows;
  }

  // last 5 months income/expense (bank-filtered; time = last 5 months)
  Future<List<Map<String, Object?>>> getLastFiveMonthsStats({
    int? bankId,
  }) async {
    final rows = await database.rawQuery(
      '''
      select
        date(date, 'start of month', 'localtime') as monthStart,
        sum(case when type = 'income' then amount else 0 end) as totalIncome,
        sum(case when type = 'expense' then amount else 0 end) as totalExpense
      from transactions
      where date(date) >= date('now', 'start of month', '-4 months', 'localtime')
        and (? is null or bankId = ?)
      group by monthStart
      order by monthStart
      ''',
      [bankId, bankId],
    );
    return rows;
  }
}
