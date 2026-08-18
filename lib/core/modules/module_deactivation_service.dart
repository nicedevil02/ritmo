import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/modules/module_content_map.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/services/snapshot_sync_service.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:sqflite/sqflite.dart';

class ModuleDeactivationService {
  ModuleDeactivationService._();

  static Future<void> deactivate(String moduleKey) async {
    final db = await DatabaseHelper.instance.database;
    final content = ModuleContentMap.findByKey(moduleKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    
    await db.transaction((txn) async {
      // 1. Clear pending reminders and cancel native alarms for module owner
      final reminders = await txn.query(
        'pending_reminders',
        where: 'ownerModule = ?',
        whereArgs: [moduleKey],
      );
      
      for (final r in reminders) {
        final id = r['id'] as String;
        try {
          await sl<AlarmPlatform>().cancelAlarm(id);
        } catch (_) {}
      }
      
      await txn.delete(
        'pending_reminders',
        where: 'ownerModule = ?',
        whereArgs: [moduleKey],
      );

      // 2. Clear occurrences for module owner
      await txn.delete(
        'routine_occurrences',
        where: 'ownerModule = ?',
        whereArgs: [moduleKey],
      );

      // 3. Clear category-associated routines' occurrences and reminders
      if (content != null && content.routineCategories.isNotEmpty) {
        final categories = content.routineCategories.toList();
        final placeholders = List.filled(categories.length, '?').join(',');
        final routineRows = await txn.query(
          'routines',
          columns: ['id'],
          where: 'category IN ($placeholders)',
          whereArgs: categories,
        );
        
        final routineIds = routineRows.map((r) => r['id'] as String).toList();
        if (routineIds.isNotEmpty) {
          final rPlaceholders = List.filled(routineIds.length, '?').join(',');
          
          final routineReminders = await txn.query(
            'pending_reminders',
            columns: ['id'],
            where: 'routineId IN ($rPlaceholders)',
            whereArgs: routineIds,
          );
          for (final rem in routineReminders) {
            final id = rem['id'] as String;
            try {
              await sl<AlarmPlatform>().cancelAlarm(id);
            } catch (_) {}
          }
          
          await txn.delete(
            'pending_reminders',
            where: 'routineId IN ($rPlaceholders)',
            whereArgs: routineIds,
          );

          await txn.delete(
            'routine_occurrences',
            where: 'routine_id IN ($rPlaceholders)',
            whereArgs: routineIds,
          );
        }
      }
      
      // 4. Set setting to false (handling aliases)
      await txn.insert(
        'app_settings', 
        {'key': moduleKey, 'value': 'false', 'updatedAt': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (moduleKey == 'module_sports_enabled' || moduleKey == 'module_supplementary_sports_enabled') {
        await txn.insert(
          'app_settings', 
          {'key': 'module_sports_enabled', 'value': 'false', 'updatedAt': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'app_settings', 
          {'key': 'module_supplementary_sports_enabled', 'value': 'false', 'updatedAt': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (moduleKey == 'module_medicine_enabled' || moduleKey == 'module_health_enabled') {
        await txn.insert(
          'app_settings', 
          {'key': 'module_medicine_enabled', 'value': 'false', 'updatedAt': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'app_settings', 
          {'key': 'module_health_enabled', 'value': 'false', 'updatedAt': now},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    // 5. Update in-memory settings cache
    try {
      await SettingsService.instance.set(moduleKey, false);
      if (moduleKey == 'module_sports_enabled' || moduleKey == 'module_supplementary_sports_enabled') {
        await SettingsService.instance.set('module_sports_enabled', false);
        await SettingsService.instance.set('module_supplementary_sports_enabled', false);
      }
      if (moduleKey == 'module_medicine_enabled' || moduleKey == 'module_health_enabled') {
        await SettingsService.instance.set('module_medicine_enabled', false);
        await SettingsService.instance.set('module_health_enabled', false);
      }
    } catch (_) {}

    // 6. Refresh application state & invalidate DayAgenda memoization
    DayAgendaService.instance.invalidateAll();
    await ModuleGate.instance.refresh();
    RitmoEvents.notifyRoutineChanged();
    await AlarmSchedulerService.scheduleNextAlarms();
    await SnapshotSyncService.syncAll();
  }
}

