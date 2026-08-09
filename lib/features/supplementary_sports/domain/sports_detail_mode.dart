import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class SportsDetailMode {
  static final ValueNotifier<bool> notifier = ValueNotifier(false);

  static Future<bool> isEnabled() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['sports_detail_mode'],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final value = rows.first['value'] == 'true';
      notifier.value = value;
      return value;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'app_settings',
        {
          'key': 'sports_detail_mode',
          'value': enabled ? 'true' : 'false',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      notifier.value = enabled;
    } catch (_) {}
  }
}
