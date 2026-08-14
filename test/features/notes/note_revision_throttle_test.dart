import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Note Revision Throttling Tests (Task A3)', () {
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
          CREATE TABLE note_revisions (
            id TEXT PRIMARY KEY,
            noteId TEXT NOT NULL,
            body TEXT NOT NULL,
            wordCount INTEGER NOT NULL DEFAULT 0,
            reason TEXT NOT NULL DEFAULT 'AUTOSAVE',
            createdAt INTEGER NOT NULL
          );
        ''');
      });

      DatabaseHelper.instance.setDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('AUTOSAVE revisions are throttled within 5 minutes, while MANUAL_SAVE is not', () async {
      final repo = NotesRepository.instance;
      final note = await repo.create(title: 'Test Note', body: 'Initial text');

      // 1. Initial creation creates 0 revisions
      var revs = await repo.listRevisions(note.id);
      expect(revs.length, 0);

      // 2. First AUTOSAVE creates a revision
      await repo.update(note.copyWith(body: 'Auto 1'), reason: 'AUTOSAVE');
      revs = await repo.listRevisions(note.id);
      expect(revs.length, 1);
      expect(revs.first.body, 'Auto 1');

      // 3. Second AUTOSAVE within 5 minutes is throttled (no new revision)
      await repo.update(note.copyWith(body: 'Auto 2'), reason: 'AUTOSAVE');
      revs = await repo.listRevisions(note.id);
      expect(revs.length, 1);
      expect(revs.first.body, 'Auto 1');

      // 4. MANUAL_SAVE bypasses throttle and always creates a revision
      await repo.update(note.copyWith(body: 'Manual Save 1'), reason: 'MANUAL_SAVE');
      revs = await repo.listRevisions(note.id);
      expect(revs.length, 2);
      expect(revs.first.reason, 'MANUAL_SAVE');
      expect(revs.first.body, 'Manual Save 1');

      // 5. RESTORE or AI_EDIT also bypasses throttle
      await repo.update(note.copyWith(body: 'AI Edit 1'), reason: 'AI_EDIT');
      revs = await repo.listRevisions(note.id);
      expect(revs.length, 3);
      expect(revs.first.reason, 'AI_EDIT');
    });
  });
}
