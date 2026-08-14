import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/catalog/notes_commands.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';
import 'package:ritmo/features/notes/logic/note_fts_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Notes Command Bus FTS Synchronization Tests (Task B1)', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath, version: 99, onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT,
            body TEXT NOT NULL DEFAULT '',
            titleNormalized TEXT NOT NULL DEFAULT '',
            bodyNormalized TEXT NOT NULL DEFAULT '',
            kind TEXT NOT NULL DEFAULT 'NOTE',
            status TEXT NOT NULL DEFAULT 'ACTIVE',
            isPrivate INTEGER NOT NULL DEFAULT 0,
            isPinned INTEGER NOT NULL DEFAULT 0,
            dayKey TEXT,
            sourceModule TEXT,
            sourceEntityId TEXT,
            captureContextJson TEXT,
            wordCount INTEGER NOT NULL DEFAULT 0,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            openedAt INTEGER,
            openCount INTEGER NOT NULL DEFAULT 0,
            reviewAt INTEGER,
            reviewStage INTEGER NOT NULL DEFAULT 0,
            trashedAt INTEGER
          );
        ''');

        await db.execute('''
          CREATE TABLE note_links (
            id TEXT PRIMARY KEY,
            noteId TEXT NOT NULL,
            linkModule TEXT NOT NULL,
            linkEntityId TEXT NOT NULL,
            linkAction TEXT,
            relation TEXT NOT NULL DEFAULT 'MENTIONS',
            createdAt INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE note_tags (
            noteId TEXT NOT NULL,
            tag TEXT NOT NULL,
            tagNormalized TEXT NOT NULL,
            source TEXT NOT NULL DEFAULT 'USER',
            createdAt INTEGER NOT NULL,
            PRIMARY KEY (noteId, tagNormalized)
          );
        ''');

        await db.execute('''
          CREATE TABLE note_revisions (
            id TEXT PRIMARY KEY,
            noteId TEXT NOT NULL,
            body TEXT NOT NULL,
            wordCount INTEGER NOT NULL DEFAULT 0,
            reason TEXT NOT NULL DEFAULT 'AUTOSAVE',
            createdAt INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE TABLE note_experience_meta (
            noteId TEXT PRIMARY KEY,
            lesson TEXT NOT NULL,
            contextText TEXT NOT NULL DEFAULT '',
            category TEXT NOT NULL DEFAULT 'GENERAL',
            importance INTEGER NOT NULL DEFAULT 3,
            occurredOnDayKey TEXT NOT NULL,
            isActive INTEGER NOT NULL DEFAULT 1,
            showCount INTEGER NOT NULL DEFAULT 0,
            acknowledgedCount INTEGER NOT NULL DEFAULT 0
          );
        ''');

        await db.execute('''
          CREATE TABLE assistant_plans (
            id TEXT PRIMARY KEY,
            titleFa TEXT NOT NULL,
            personaId TEXT NOT NULL,
            status TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            appliedAt INTEGER,
            undoneAt INTEGER
          );
        ''');

        await db.execute('''
          CREATE TABLE assistant_audit_log (
            id TEXT PRIMARY KEY,
            planId TEXT NOT NULL,
            stepIndex INTEGER NOT NULL,
            commandId TEXT NOT NULL,
            humanDescriptionFa TEXT NOT NULL,
            payloadJson TEXT NOT NULL,
            inverseJson TEXT,
            targetKey TEXT,
            status TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            appliedAt INTEGER,
            undoneAt INTEGER,
            personaId TEXT
          );
        ''');

        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updatedAt INTEGER NOT NULL
          );
        ''');

        await db.execute('''
          CREATE VIRTUAL TABLE notes_fts USING fts5(
            noteId UNINDEXED,
            titleN,
            bodyN,
            tagsN
          );
        ''');

        await db.insert('app_settings', {
          'key': 'notes_fts_available',
          'value': 'true',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      });

      DatabaseHelper.instance.setDatabaseForTesting(db);
      DatabaseHelper.databaseInstance = db;
      NoteFtsEngine.instance.resetForTesting();
      registerNotesCommands();
    });

    tearDown(() async {
      await db.close();
    });

    test('Executing note.create indexes note in FTS, deleting/archiving removes it', () async {
      final bus = RitmoCommandBus.instance;

      // 1. Create a note via Command Bus
      final plan = CommandPlan(
        titleFa: 'ایجاد یادداشت جدید',
        personaId: 'global',
        steps: [
          CommandStep(
            commandId: 'note.create',
            payload: {
              'title': 'تمرین تمرکز',
              'body': 'روش‌های افزایش بهره‌وری و تمرکز عمیق',
              'tags': ['بهره‌وری', 'ذهن'],
            },
          ),
        ],
      );

      final planRes = await bus.execute(plan);
      expect(planRes.success, isTrue);
      final noteId = planRes.results.first.outputData?['noteId'] as String?;
      expect(noteId, isNotNull);

      // Search via FTS
      var searchResults = await NoteFtsEngine.instance.search('تمرکز');
      expect(searchResults.length, 1);
      expect(searchResults.first.id, noteId);

      // 2. Archive note via Command Bus -> should be removed from active FTS index
      final archivePlan = CommandPlan(
        titleFa: 'بایگانی یادداشت',
        personaId: 'global',
        steps: [
          CommandStep(
            commandId: 'note.archive',
            payload: {'noteId': noteId},
          ),
        ],
      );

      final archiveRes = await bus.execute(archivePlan);
      expect(archiveRes.success, isTrue);

      searchResults = await NoteFtsEngine.instance.search('تمرکز');
      expect(searchResults.length, 0);

      // 3. Restore note via Command Bus -> should be re-indexed into FTS
      final restorePlan = CommandPlan(
        titleFa: 'بازیابی یادداشت',
        personaId: 'global',
        steps: [
          CommandStep(
            commandId: 'note.restore',
            payload: {'noteId': noteId},
          ),
        ],
      );

      final restoreRes = await bus.execute(restorePlan);
      expect(restoreRes.success, isTrue);

      searchResults = await NoteFtsEngine.instance.search('تمرکز');
      expect(searchResults.length, 1);
      expect(searchResults.first.id, noteId);

      // 4. Delete note via Command Bus -> should be removed from active FTS index
      final deletePlan = CommandPlan(
        titleFa: 'حذف یادداشت',
        personaId: 'global',
        steps: [
          CommandStep(
            commandId: 'note.delete',
            payload: {'noteId': noteId},
          ),
        ],
      );

      final deleteRes = await bus.execute(deletePlan);
      expect(deleteRes.success, isTrue);

      searchResults = await NoteFtsEngine.instance.search('تمرکز');
      expect(searchResults.length, 0);
    });
  });
}
