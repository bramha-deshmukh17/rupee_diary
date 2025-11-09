import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // Create a singleton instance
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // Getter for the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ruppediary.db'); // Database file name
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate, // This function runs when the DB is first created
    );
  }

  // Create the database table
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

  // FUNCTION TO UPDATE SETTINGS
  Future<int> updateSetting(String key, String value) async {
    final db = await database;
    return await db.update(
      'settings',
      {'settings_value': value},
      where: 'settings_key = ?',
      whereArgs: [key],
    );
  }

  // FUNCTION TO GET ALL SETTINGS AS A MAP
  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('settings');
    if (maps.isEmpty) return {};

    // Convert the List<Map> into a single Map<String, String>
    return Map.fromEntries(
      maps.map((map) => MapEntry(map['settings_key'], map['settings_value'])),
    );
  }

  // BILL REMINDER FUNCTIONS
  Future<int> insertBillReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    reminder['created_at'] = now;
    reminder['updated_at'] = now;
    return await db.insert('bill_reminders', reminder);
  }

  Future<List<Map<String, dynamic>>> getBillReminders() async {
    final db = await database;
    return await db.query('bill_reminders', orderBy: 'due_date ASC');
  }

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

  Future<int> deleteBillReminder(int id) async {
    final db = await database;
    return await db.delete('bill_reminders', where: 'id = ?', whereArgs: [id]);
  }

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
