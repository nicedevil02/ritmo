import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV89PregnancyDataSync extends Migration {
  @override
  bool get requiresTransaction => false;
  @override
  int get version => 89;

  @override
  Future<void> down(DatabaseExecutor db) async {}

  @override
  Future<void> up(DatabaseExecutor db) async {
    RitmoLog.info('MigrationV89', 'Applying V89 pregnancy data sync & index fixes...');

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    try {
      // 1. Check if legacy cycle_pregnancy_mode is active while pregnancy_tracker has no active row
      final activeTrackers = await db.query('pregnancy_tracker', where: 'isActive = 1', limit: 1);
      if (activeTrackers.isEmpty) {
        final settingsRows = await db.query(
          'app_settings',
          where: "key IN ('cycle_pregnancy_mode', 'cycle_pregnancy_start_date', 'cycle_pregnancy_due_date')",
        );
        final settingsMap = {for (var r in settingsRows) r['key'] as String: r['value'] as String};

        if (settingsMap['cycle_pregnancy_mode'] == 'true' && settingsMap['cycle_pregnancy_start_date'] != null) {
          final lmpStr = settingsMap['cycle_pregnancy_start_date']!;
          final eddStr = settingsMap['cycle_pregnancy_due_date'] ??
              DateTime.tryParse(lmpStr)?.add(const Duration(days: 280)).toIso8601String().substring(0, 10) ??
              '';
          final trackerId = 'preg_migrated_${DateTime.now().millisecondsSinceEpoch}';

          final trackerTableInfo = await db.rawQuery("PRAGMA table_info('pregnancy_tracker')");
          final trackerCols = trackerTableInfo.map((c) => c['name'] as String).toSet();

          final row = <String, dynamic>{
            'id': trackerId,
            'lmpDate': lmpStr,
            'isActive': 1,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          };
          if (trackerCols.contains('estimatedDueDate')) row['estimatedDueDate'] = eddStr;
          if (trackerCols.contains('expectedDueDate')) row['expectedDueDate'] = eddStr;
          if (trackerCols.contains('currentWeek')) row['currentWeek'] = 1;
          if (trackerCols.contains('currentTrimester')) row['currentTrimester'] = 1;

          await db.insert('pregnancy_tracker', row, conflictAlgorithm: ConflictAlgorithm.replace);

          // Migrate legacy kicks if any
          final kickRows = await db.query(
            'app_settings',
            where: "key LIKE 'pregnancy_kicks_%'",
          );
          for (final row in kickRows) {
            final key = row['key'] as String;
            final dateStr = key.replaceFirst('pregnancy_kicks_', '');
            final count = int.tryParse(row['value'] as String? ?? '') ?? 0;
            if (count > 0) {
              await db.insert('kick_counts', {
                'id': 'kick_mig_${trackerId}_$dateStr',
                'pregnancyId': trackerId,
                'loggedAt': nowMs,
                'kickCount': count,
                'sessionDate': dateStr,
                'createdAt': nowMs,
              });
            }
          }
          await db.delete('app_settings', where: "key LIKE 'pregnancy_kicks_%' OR key LIKE 'pregnancy_last_kick_%'");
        }
      }
    } catch (e, st) {
      RitmoLog.warning('MigrationV89', 'Error during pregnancy tracker data migration: $e', st);
    }

    // 2. Clean up duplicate symptoms in pregnancy_symptoms before unique index creation (PREG-06)
    try {
      await db.execute('''
        DELETE FROM pregnancy_symptoms 
        WHERE rowid NOT IN (
          SELECT MIN(rowid) 
          FROM pregnancy_symptoms 
          GROUP BY pregnancyId, date, symptom
        )
      ''');
    } catch (e) {
      RitmoLog.warning('MigrationV89', 'Error cleaning duplicate symptoms: $e');
    }

    // 3. Create Unique Indexes (PREG-06, PREG-07)
    try {
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_preg_sym_unique
          ON pregnancy_symptoms(pregnancyId, date, symptom);
      ''');
    } catch (e) {
      RitmoLog.warning('MigrationV89', 'Error creating idx_preg_sym_unique: $e');
    }

    try {
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_preg_only_one_active
          ON pregnancy_tracker(isActive) WHERE isActive = 1;
      ''');
    } catch (e) {
      RitmoLog.warning('MigrationV89', 'Error creating idx_preg_only_one_active: $e');
    }

    // 4. Create Standard Indexes on 5 Pregnancy Tables (PREG-18)
    await db.execute('CREATE INDEX IF NOT EXISTS idx_preg_chk_pid ON pregnancy_checkups(pregnancyId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_preg_sym_pid_date ON pregnancy_symptoms(pregnancyId, date);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_kick_pid_logged ON kick_counts(pregnancyId, loggedAt);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_contr_pid_logged ON contraction_timer(pregnancyId, loggedAt);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_preg_tracker_active ON pregnancy_tracker(isActive);');

    RitmoLog.info('MigrationV89', 'V89 migration applied successfully.');
  }
}
