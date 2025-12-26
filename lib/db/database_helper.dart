import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'operations/bank.dart';
import 'operations/bill_reminder.dart';
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

    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(SettingDao.create);
    await db.execute(SettingDao.insertDefault);

    await db.execute(BankDao.createTable);

    await db.execute(CategoryDao.createTable);

    await db.execute(TransactionsDao.createTable);
    await db.execute(BillReminderDao.createTable);
  }


  /// export to app documents (no permissions)
  Future<File> exportBackupJson() async {
    final db = await database;

    const tables = <String>[
      'settings',
      'bank',
      'categories',
      'transactions',
      'bill_reminders',
    ];
    final backup = <String, dynamic>{
      'createdAt': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{},
    };

    for (final t in tables) {
      final rows = await db.rawQuery('select * from $t');
      (backup['tables'] as Map<String, dynamic>)[t] = rows;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'rupeediary_backup.json'));
    await file.writeAsString(jsonEncode(backup), flush: true);
    return file;
  }
}

extension DbRestore on DatabaseHelper {
  Future<File> getDefaultBackupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'rupeediary_backup.json'));
  }

  /// Restores from the default backup file in app documents.
  /// - does NOT require file picker
  /// - inserts only columns that exist in the current DB tables
  /// - clears existing rows before inserting
  Future<void> restoreBackupFromDefaultLocation() async {
    final backupFile = await getDefaultBackupFile();
    if (!await backupFile.exists()) {
      throw Exception('backup file not found: ${backupFile.path}');
    }
    await restoreFromBackupJson(backupFile);
  }

  Future<void> restoreFromBackupJson(File backupFile) async {
    final db = await database;

    final decoded =
        jsonDecode(await backupFile.readAsString()) as Map<String, dynamic>;
    final tables =
        (decoded['tables'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    await db.transaction((txn) async {
      await txn.execute('pragma foreign_keys = off');

      // Restore in a safer order (parents first). Only restores tables present in backup.
      final preferredOrder = <String>[
        'settings',
        'bank',
        'categories',
        'transactions',
        'bill_reminders',
        'bill_reminder', // support legacy table name if your backup used it
      ];

      // Build ordered keys: preferred first, then whatever remains
      final keys = <String>[
        ...preferredOrder.where(tables.containsKey),
        ...tables.keys.where((k) => !preferredOrder.contains(k)),
      ];

      for (final table in keys) {
        final rowsDynamic = tables[table];
        if (rowsDynamic is! List) continue;

        final exists = await _tableExists(txn, table);
        if (!exists) {
          debugPrint('restore: skip missing table $table');
          continue;
        }

        final cols = await _columnNames(txn, table);

        // clear existing data (you can remove this if you prefer merge)
        await txn.delete(table);

        for (final r in rowsDynamic) {
          if (r is! Map) continue;

          // insert only columns that exist in current schema
          final row = <String, Object?>{};
          for (final entry in r.entries) {
            final key = entry.key?.toString();
            if (key == null) continue;
            if (!cols.contains(key)) continue;
            row[key] = entry.value;
          }

          // if row becomes empty (schema mismatch), skip
          if (row.isEmpty) continue;

          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        debugPrint('restore: restored ${rowsDynamic.length} rows into $table');
      }

      await txn.execute('pragma foreign_keys = on');
    });
  }

  Future<bool> _tableExists(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "select name from sqlite_master where type='table' and name=? limit 1",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> _columnNames(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery('pragma table_info($table)');
    return rows.map((e) => e['name']?.toString()).whereType<String>().toSet();
  }
}
