import 'package:sqflite/sqflite.dart';

import '../model/setting.dart';

class SettingDao {
  final Database? db;
  SettingDao(this.db);

  //settings table
  static const create = '''
      create table settings(
        id integer primary key autoincrement,
        settingsKey text not null,
        settingsValue text
      );
      ''';

  // Insert default settings
  static const insertDefault = '''
      insert into settings (settingsKey, settingsValue) values
      ('notifications', 'enabled'),
      ('theme', 'disabled'),
      ('authentication', 'disabled'),
      ('password', null);
    ''';

  // update settings
  Future<void> updateSetting(SettingModel setting) async {
    final result = await db!.update(
      'settings',
      {'settingsValue': setting.settingsValue},
      where: 'settingsKey = ?',
      whereArgs: [setting.settingsKey],
    );

    // If no row was updated insert new one
    if (result == 0) {
      await db!.insert(
        'settings',
        setting.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // get all settings
  Future<List<SettingModel>> getSettings() async {
    final List<Map<String, dynamic>> maps = await db!.query('settings');
    return maps.map((map) => SettingModel.fromMap(map)).toList();
  }
}
