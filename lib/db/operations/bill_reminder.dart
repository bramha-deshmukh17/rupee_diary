import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart'; // for debugPrint
import '../model/bill_reminder.dart';

class BillReminderDao {
  final Database database;
  BillReminderDao(this.database);

  static const createTable = '''
    create table bill_reminders(
      id integer primary key autoincrement,
      title text not null,
      amount real not null,
      due_date text not null,          -- store as ISO8601 string
      category int not null,
      notes text,
      is_recurring integer default 0,
      is_paid integer default 0,
      foreign key (category) references category(id)
    );
  ''';

  // Helper: ensure due_date is a string (ISO8601) if a DateTime was provided.
  Map<String, dynamic> _normalizeMap(Map<String, dynamic> m) {
    final copy = <String, dynamic>{}..addAll(m);
    if (copy.containsKey('due_date') && copy['due_date'] is DateTime) {
      copy['due_date'] = (copy['due_date'] as DateTime).toIso8601String();
    }
    return copy;
  }

  // ADD A BILL REMINDER
  Future<int> insertBillReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    final normalized = _normalizeMap(reminder);
    return await db.insert('bill_reminders', normalized);
  }

  // GET ALL BILL REMINDERS
  Future<List<BillReminderModel>> getAll() async {
    final db = await database;
    final rows = await db.query('bill_reminders', orderBy: 'due_date ASC');

    // If your BillReminderModel.fromMap expects a DateTime in dueDate, ensure it converts there.
    return rows.map(BillReminderModel.fromMap).toList();
  }

  // UPDATE A BILL REMINDER
  Future<int> updateBillReminder(int id, Map<String, dynamic> reminder) async {
    final db = await database;
    final normalized = _normalizeMap(reminder);
    return await db.update(
      'bill_reminders',
      normalized,
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
      {'is_paid': isPaid ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MOVE TO NEXT RECURRENCE (store nextDue as ISO8601 string)
  Future<int> advanceRecurringReminder(int id, DateTime nextDue) async {
    final db = await database;
    return await db.update(
      'bill_reminders',
      {'due_date': nextDue.toIso8601String(), 'is_paid': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Debug parsed models (relies on BillReminderModel.fromMap)
  Future<void> debugPrintAllModels() async {
    final list = await getAll();
    debugPrint('📌 ===== BILL REMINDERS (MODELS) =====');
    if (list.isEmpty) {
      debugPrint('⚠️ No reminders found');
    } else {
      for (final r in list) {
        debugPrint(
          '🧾 ID: ${r.id} | TITLE: ${r.title} | ₹${r.amount} | DUE: ${r.dueDate.toIso8601String()} | RECURRING: ${r.isRecurring} | PAID: ${r.isPaid}',
        );
      }
    }
    debugPrint('📌 ===== END =====');
  }
}
