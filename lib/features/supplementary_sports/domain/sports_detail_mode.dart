import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';

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
    } catch (e, st) {
      RitmoLogger.warning(
        'Failed to query sports_detail_mode: $e',
        error: e,
        stack: st,
      );
      return false;
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await UpsertHelper.upsert(
        db,
        'app_settings',
        {
          'key': 'sports_detail_mode',
          'value': enabled ? 'true' : 'false',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictColumns: const ['key'],
      );
      notifier.value = enabled;
    } catch (e, st) {
      RitmoLogger.error(
        'Failed to set sports_detail_mode: $e',
        error: e,
        stack: st,
      );
    }
  }
}
