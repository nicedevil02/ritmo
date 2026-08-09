import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/modules/module_content_map.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/services/snapshot_sync_service.dart';
import 'package:sqflite/sqflite.dart';

class ModuleDeactivationService {
  ModuleDeactivationService._();

  static Future<void> deactivate(String moduleKey) async {
    final db = await DatabaseHelper.instance.database;
    final content = ModuleContentMap.findByKey(moduleKey);
    
    await db.transaction((txn) async {
      // 1. Clear pending reminders and cancel native alarms
      final reminders = await txn.query(
        'pending_reminders',
        where: 'ownerModule = ?',
        whereArgs: [moduleKey],
      );
      
      for (final r in reminders) {
        final id = r['id'] as String;
        await sl<AlarmPlatform>().cancelAlarm(id);
      }
      
      await txn.delete(
        'pending_reminders',
        where: 'ownerModule = ?',
        whereArgs: [moduleKey],
      );

      // 2. Clear occurrences
      await txn.delete(
        'routine_occurrences',
        where: 'ownerModule = ?',
        whereArgs: [moduleKey],
      );

      // 3. Clear data tables owned by this module
      if (content != null) {
        for (final table in content.dataTables) {
          try {
            await txn.delete(table);
          } catch (e) {
            debugPrint('[ModuleDeactivationService] Warning: Table $table delete failed: $e');
          }
        }
      }
      
      // 4. Set setting to false
      await txn.insert(
        'app_settings', 
        {'key': moduleKey, 'value': 'false'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    // 5. Refresh application state
    await ModuleGate.instance.refresh();
    RitmoEvents.notifyRoutineChanged();
    await AlarmSchedulerService.scheduleNextAlarms();
    await SnapshotSyncService.syncAll();
  }
}
