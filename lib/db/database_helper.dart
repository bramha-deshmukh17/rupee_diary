import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'operations/bank.dart';
import 'operations/bill_reminder.dart';
import 'operations/budget.dart';
import 'operations/category.dart';
import 'operations/settings.dart';
import 'operations/transactions.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  late final SettingDao settingDao;
  late final BankDao bankDao;
  late final CategoryDao categoryDao;
  late final TransactionsDao transactionsDao;
  late final BillReminderDao billReminderDao;
  late final BudgetDao budgetDao;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'rupeediary.db');

    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => db.execute('pragma foreign_keys = on'),
      onCreate: _onCreate,
    );

    settingDao = SettingDao(db);
    bankDao = BankDao(db);
    categoryDao = CategoryDao(db);
    transactionsDao = TransactionsDao(db);
    billReminderDao = BillReminderDao(db);
    budgetDao = BudgetDao(db);

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(SettingDao.create);
    await db.execute(SettingDao.insertDefault);

    await db.execute(BankDao.createTable);

    await db.execute(CategoryDao.createTable);
    await db.execute(CategoryDao.insertDefaultCategories);
    await db.execute(BudgetDao.createTable);

    await db.execute(TransactionsDao.createTable);
    await db.execute(BillReminderDao.createTable);
  }
}
