import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'operations/bill_reminder.dart';
import 'operations/settings.dart';

class DatabaseHelper {
  // Singleton instance 
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  // DAO instances
  late final SettingDao settingDao;
  late final BillReminderDao billReminderDao;

  // Public getter for DB
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize DB THEN DAOs
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rupeediary.db');

    final db = await openDatabase(path, version: 1, onCreate: _onCreate);

    // Initialize DAOs only after DB is ready
    billReminderDao = BillReminderDao(db);
    settingDao = SettingDao(db);

    return db;
  }

  // Create tables
  Future<void> _onCreate(Database db, int version) async {
    await db.execute(SettingDao.create);
    await db.execute(SettingDao.insertDefault);
    await db.execute(BillReminderDao.createTable);
  }
}
