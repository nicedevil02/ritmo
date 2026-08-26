import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v134_study_hardening.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MigrationV134StudyHardening Unit Tests', () {
    test('Migration v134 adds phaseAccumulatedSeconds to study_active_session', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE study_active_session (
              id TEXT PRIMARY KEY,
              subjectId TEXT,
              topicId TEXT,
              mode TEXT NOT NULL DEFAULT 'LEARN',
              startedAtMs INTEGER NOT NULL,
              accumulatedSeconds INTEGER NOT NULL DEFAULT 0,
              isPaused INTEGER NOT NULL DEFAULT 0,
              plannedMinutes INTEGER,
              pomodoroPhase TEXT DEFAULT 'FOCUS',
              pomodoroCycle INTEGER DEFAULT 1,
              targetSeconds INTEGER DEFAULT 1500,
              createdAt INTEGER NOT NULL
            );
          ''');
        },
      );

      final migration = MigrationV134StudyHardening();
      await migration.up(db);

      final cols = await db.rawQuery('PRAGMA table_info(study_active_session)');
      final colNames = cols.map((c) => c['name'] as String).toList();
      expect(colNames, contains('phaseAccumulatedSeconds'));

      await db.close();
    });
  });
}
