import 'package:sqflite/sqflite.dart';
import '../model/bill_reminder.dart';

class BillReminderDao {
  final Database database;
  BillReminderDao(this.database);

  static const table = 'bill_reminders';

  // SQL to create the bill_reminders table
  static const createTable = '''
    create table if not exists bill_reminders (
      id integer primary key autoincrement,
      title text not null,
      amount real not null,
      dueDate text not null,
      categoryId integer,
      notes text,
      isRecurring integer not null default 0,
      isPaid integer not null default 0,

      foreign key (categoryId) references categories(id) on delete set null
    )
  ''';

  // Helper: ensure dueDate is a string (ISO8601) if a DateTime was provided.
  Map<String, dynamic> _normalizeMap(Map<String, dynamic> m) {
    final copy = <String, dynamic>{}..addAll(m);
    if (copy.containsKey('dueDate') && copy['dueDate'] is DateTime) {
      copy['dueDate'] = (copy['dueDate'] as DateTime).toIso8601String();
    }
    return copy;
  }

  // add bill reminder
  Future<int> insertBillReminder(Map<String, dynamic> reminder) async {
    final normalized = _normalizeMap(reminder);
    return await database.insert(table, normalized);
  }

  // get all bill reminders
  Future<List<BillReminderModel>> getAll() async {
    final rows = await database.query(table, orderBy: 'datetime(dueDate) asc');
    return rows.map(BillReminderModel.fromMap).toList();
  }

  // update a bill reminder
  Future<int> updateBillReminder(int id, Map<String, dynamic> reminder) async {
    final normalized = _normalizeMap(reminder);
    return await database.update(
      table,
      normalized,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // delete a bill reminder
  Future<int> deleteBillReminder(int id) async {
    return await database.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // mark as paid
  Future<int> markBillAsPaid(int id, bool isPaid) async {
    return await database.update(
      table,
      {'isPaid': isPaid ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // store nextDue as ISO8601 string
  Future<int> advanceRecurringReminder(int id, DateTime nextDue) async {
    return await database.update(
      table,
      {'dueDate': nextDue.toIso8601String(), 'isPaid': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
