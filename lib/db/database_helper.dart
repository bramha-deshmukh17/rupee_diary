import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:rupee_diary/backup/crypto_utils.dart';
import 'package:rupee_diary/utility/snack.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../backup/backup_metadata.dart';
import './operations/bank.dart';
import './operations/bill_reminder.dart';
import './operations/budget.dart';
import './operations/category.dart';
import './operations/settings.dart';
import './operations/transactions.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  late SettingDao settingDao;
  late BankDao bankDao;
  late CategoryDao categoryDao;
  late TransactionsDao transactionsDao;
  late BillReminderDao billReminderDao;
  late BudgetDao budgetDao;

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

  Future<void> _reopenDatabase() async {
    final db = await _initDatabase();
    _db = db;
  }

  /// Get DB file
  Future<File> _getDbFile() async {
    final dbPath = await getDatabasesPath();
    return File(p.join(dbPath, 'rupeediary.db'));
  }

  Future<bool> exportEncryptedBackup(String password) async {
    try {
      // 1 Get DB file
      final dbFile = await _getDbFile();
      if (!await dbFile.exists()) {
        throw Exception("Database not found");
      }

      // 2 Read DB bytes FIRST
      final dbBytes = await dbFile.readAsBytes();

      // 3 Close DB AFTER reading
      if (_db != null) {
        await _db!.close();
        _db = null;
      }

      // 4 Create metadata
      final metadata = BackupMetadata(
        appName: "RupeeDiary",
        backupVersion: 1,
        dbVersion: 1,
        createdAt: DateTime.now().toIso8601String(),
      );

      final metaJson = jsonEncode(metadata.toJson());
      final metaBytes = utf8.encode(metaJson);
      final metaLength = ByteData(4)..setUint32(0, metaBytes.length);

      final combinedBytes = Uint8List.fromList([
        ...metaLength.buffer.asUint8List(),
        ...metaBytes,
        ...dbBytes,
      ]);

      // 5 Encrypt
      final encryptedBytes = CryptoUtils.encryptBytes(combinedBytes, password);

      // 6 Save encrypted bytes (Android-safe).
      // some devices may background the app and return null even if saved.
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save encrypted backup',
        fileName: 'rupeediary_${DateTime.now().millisecondsSinceEpoch}.rdb',
        bytes: encryptedBytes,
      );

      //  reached here without throwing, treat it as success.
      return true;
    } catch (e) {
      return false;
    } finally {
      // IMPORTANT: reopen DB but do NOT let errors here escape.
      try {
        await _reopenDatabase();
      } catch (e) {
        showSnack("Failed to open reopen db", p.context as BuildContext, error: true);
        showSnack("Re-open app now", p.context as BuildContext);
      }
    }
  }

  Future<bool> restoreEncryptedBackup(String password) async {
    File? tempDbFile;

    try {
      // 1 Pick a file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true, // prefer bytes on Android
      );

      if (result == null) {
        return false;
      }

      final picked = result.files.single;

      // Optional UX hint: if path exists but extension not .rdb, warn user.
      final pickedName = picked.name;
      if (!pickedName.toLowerCase().endsWith('.rdb')) {
        // Not fatal — some users may rename files. We'll still try to parse.
        showSnack(
          "Please select a .rdb backup file",
          p.context as BuildContext,
          error: true,
        );
        return false;
      }

      // 2 Get bytes either from in-memory or from file path fallback
      Uint8List encryptedBytes;
      if (picked.bytes != null && picked.bytes!.isNotEmpty) {
        encryptedBytes = picked.bytes!;
      } else if (picked.path != null) {
        encryptedBytes = await File(picked.path!).readAsBytes();
      } else {
        return false;
      }

      // 3 Try decrypting — if password wrong or file corrupted, CryptoUtils will throw.
      final decryptedBytes = CryptoUtils.decryptBytes(encryptedBytes, password);

      // 4 Extract metadata length
      final byteData = ByteData.sublistView(decryptedBytes);
      if (byteData.lengthInBytes < 4) {
        throw Exception("Decrypted data too small for metadata length");
      }
      final metaLength = byteData.getUint32(0);

      if (metaLength <= 0 || metaLength > 10 * 1024) {
        throw Exception("Invalid metadata length: $metaLength");
      }

      final metaStart = 4;
      final metaEnd = metaStart + metaLength;
      if (decryptedBytes.length < metaEnd) {
        throw Exception(
          "Decrypted data truncated: expected metadata end $metaEnd",
        );
      }

      final metaJson = utf8.decode(decryptedBytes.sublist(metaStart, metaEnd));
      final metadata = BackupMetadata.fromJson(jsonDecode(metaJson));

      // 5 Validate metadata strictly
      if (metadata.appName != "RupeeDiary") {
        throw Exception("Backup does not belong to RupeeDiary");
      }
      if (metadata.backupVersion != 1) {
        throw Exception("Unsupported backup format: ${metadata.backupVersion}");
      }
      if (metadata.dbVersion != 1) {
        throw Exception(
          "Backup DB version (${metadata.dbVersion}) is incompatible",
        );
      }

      // 6 Extract DB bytes and write to a temp DB file
      final dbBytes = decryptedBytes.sublist(metaEnd);
      final dbPath = await getDatabasesPath();
      tempDbFile = File(p.join(dbPath, 'rupeediary_restore_tmp.db'));
      await tempDbFile.writeAsBytes(dbBytes, flush: true);

      // 7 Validate SQLite integrity (PRAGMA integrity_check returns 'ok')
      final testDb = await openDatabase(tempDbFile.path, readOnly: true);
      final integrityRows = await testDb.rawQuery('PRAGMA integrity_check');
      await testDb.close();

      if (integrityRows.isEmpty ||
          !(integrityRows.first.values.first?.toString().toLowerCase().contains(
                'ok',
              ) ??
              false)) {
        throw Exception("SQLite integrity_check failed: $integrityRows");
      }

      // 8 Close current DB and replace atomically
      if (_db != null) {
        await _db!.close();
        _db = null;
      }

      final liveDbFile = await _getDbFile();
      await tempDbFile.rename(liveDbFile.path);

      return true;
    } catch (e) {
      return false;
    } finally {
      // clean up the temp file and reopen DB safely (non-fatal)
      try {
        if (tempDbFile != null && await tempDbFile.exists()) {
          await tempDbFile.delete();
        }
      } catch (e) {
        // ignore
      }

      try {
        await _reopenDatabase();
      } catch (e) {
        showSnack("Failed to open reopen db", p.context as BuildContext, error: true);
        showSnack("Re-open app now", p.context as BuildContext);
      }
    }
  }
}
