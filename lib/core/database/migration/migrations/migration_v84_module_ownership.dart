import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/modules/module_content_map.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV84 extends Migration {
  @override
  int get version => 84;

  @override
  Future<void> up(DatabaseExecutor db) async {
    try {
      await safeAddColumn(db, 'pending_reminders', 'ownerModule', 'TEXT');
      await safeAddColumn(db, 'routine_occurrences', 'ownerModule', 'TEXT');
      await safeAddColumn(db, 'worship_completions', 'quality', 'TEXT');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_pending_owner_module ON pending_reminders(ownerModule);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_occurrence_owner_module ON routine_occurrences(ownerModule);');

      // Backfill pending_reminders
      final pendingRows = await db.query('pending_reminders', columns: ['id', 'routineId']);
      int orphanCount = 0;
      for (final row in pendingRows) {
        final id = row['id'] as String;
        final routineId = row['routineId'] as String?;
        String? owner;

        if (routineId != null) {
          final routines = await db.query('routines', columns: ['category'], where: 'id = ?', whereArgs: [routineId]);
          if (routines.isNotEmpty) {
            final cat = routines.first['category'] as String?;
            if (cat != null) {
              owner = ModuleContentMap.ownerOfCategory(cat);
            }
          }
        }

        if (owner == null) {
          if (id.startsWith('visit_')) {
            owner = 'module_medicine_enabled';
          } else if (id.startsWith('cycle_private_reminder')) {
            owner = 'module_cycle_enabled';
          } else if (id.startsWith('daily_planning_nudge')) {
            owner = 'module_today_routines';
          }
        }

        if (owner == null) {
          orphanCount++;
        } else {
          await db.update('pending_reminders', {'ownerModule': owner}, where: 'id = ?', whereArgs: [id]);
        }
      }
      debugPrint('[MigrationV84] Backfilled pending_reminders. Orphans found: $orphanCount');

      // Backfill routine_occurrences
      final occRows = await db.query('routine_occurrences', columns: ['date', 'routine_id']);
      for (final row in occRows) {
        final date = row['date'] as String;
        final rId = row['routine_id'] as String;
        
        final routines = await db.query('routines', columns: ['category'], where: 'id = ?', whereArgs: [rId]);
        if (routines.isNotEmpty) {
          final cat = routines.first['category'] as String?;
          if (cat != null) {
            final owner = ModuleContentMap.ownerOfCategory(cat);
            if (owner != null) {
              await db.update('routine_occurrences', {'ownerModule': owner}, where: 'routine_id = ? AND date = ?', whereArgs: [rId, date]);
            }
          }
        }
      }

      // Backfill worship_completions quality
      // Currently resultType might be QADA_ADDED.
      final wRows = await db.query('worship_completions', columns: ['id', 'resultType']);
      for (final row in wRows) {
        final id = row['id'] as String;
        final res = row['resultType'] as String;
        
        final quality = res == 'QADA_ADDED' ? 'QADA' : 'IN_TIME';
        await db.update('worship_completions', {'quality': quality}, where: 'id = ?', whereArgs: [id]);
      }

      // Settings
      await db.insert('app_settings', {'key': 'worship_prayer_reminders_enabled', 'value': 'true'}, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert('app_settings', {'key': 'worship_prayer_reminder_offset_minutes', 'value': '10'}, conflictAlgorithm: ConflictAlgorithm.ignore);

      debugPrint('[MigrationV84] Migration completed successfully.');
    } catch (e, st) {
      debugPrint('[MigrationV84] Error: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    // SQLite has limited drop column support, so down is typically empty for columns
  }
}
