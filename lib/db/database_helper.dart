import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // 🔥 Singleton instance (recommended pattern)
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  // Public getter for the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ruppediary.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Create tables and insert initial settings
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      create table settings(
        id integer primary key autoincrement,
        settings_key text not null,
        settings_value text not null check (settings_value in ('enabled', 'disabled'))
      );
    ''');

    await db.execute('''
      insert into settings (settings_key, settings_value) values
      ('notifications', 'disabled'),
      ('theme', 'disabled');
    ''');

    await db.execute('''
      create table bill_reminders(
        id integer primary key autoincrement,
        title text not null,
        amount real not null,
        due_date text not null,
        category text not null,
        notes text,
        is_recurring integer default 0,
        recurrence_type text,
        is_paid integer default 0,
        created_at text not null,
        updated_at text not null
      );
    ''');
  }

  // UPDATE A SETTING
  Future<int> updateSetting(String key, String value) async {
    final db = await database;
    return await db.update(
      'settings',
      {'settings_value': value},
      where: 'settings_key = ?',
      whereArgs: [key],
    );
  }

  // GET ALL SETTINGS AS A MAP
  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('settings');

    if (maps.isEmpty) return {};

    return Map.fromEntries(
      maps.map((map) => MapEntry(map['settings_key'], map['settings_value'])),
    );
  }

  // ADD A BILL REMINDER
  Future<int> insertBillReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    reminder['created_at'] = now;
    reminder['updated_at'] = now;

    return await db.insert('bill_reminders', reminder);
  }

  // GET ALL BILL REMINDERS
  Future<List<Map<String, dynamic>>> getBillReminders() async {
    final db = await database;
    return await db.query('bill_reminders', orderBy: 'due_date ASC');
  }

  // UPDATE A BILL REMINDER
  Future<int> updateBillReminder(int id, Map<String, dynamic> reminder) async {
    final db = await database;
    reminder['updated_at'] = DateTime.now().toIso8601String();

    return await db.update(
      'bill_reminders',
      reminder,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DELETE A BILL REMINDER
  Future<int> deleteBillReminder(int id) async {
    final db = await database;
    return await db.delete('bill_reminders', where: 'id = ?', whereArgs: [id]);
  }

  // MARK BILL AS PAID
  Future<int> markBillAsPaid(int id, bool isPaid) async {
    final db = await database;

    return await db.update(
      'bill_reminders',
      {
        'is_paid': isPaid ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MOVE TO NEXT RECURRENCE
  Future<int> advanceRecurringReminder(int id, DateTime nextDue) async {
    final db = await database;

    return await db.update(
      'bill_reminders',
      {
        'due_date': nextDue.toIso8601String(),
        'is_paid': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
