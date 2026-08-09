import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Notes Data Layer Tests (D-09)', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath, version: 86, onCreate: (db, v) async {
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
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_note_links_unique ON note_links(noteId, linkModule, linkEntityId, relation);');

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
          CREATE TABLE note_attachments (
            id TEXT PRIMARY KEY,
            noteId TEXT NOT NULL,
            kind TEXT NOT NULL DEFAULT 'IMAGE',
            fileName TEXT NOT NULL,
            relativePath TEXT NOT NULL,
            fileSizeBytes INTEGER NOT NULL,
            mimeType TEXT,
            caption TEXT,
            createdAt INTEGER NOT NULL
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
            contextText TEXT,
            category TEXT NOT NULL DEFAULT 'GENERAL',
            importance INTEGER NOT NULL DEFAULT 3,
            occurredOnDayKey TEXT,
            isActive INTEGER NOT NULL DEFAULT 1,
            showCount INTEGER NOT NULL DEFAULT 0,
            lastShownAtDayKey TEXT,
            acknowledgedCount INTEGER NOT NULL DEFAULT 0
          );
        ''');
      });

      DatabaseHelper.databaseInstance = db;
    });

    tearDown(() async {
      await db.close();
    });

    test('notes_repository_crud_test', () async {
      final repo = NotesRepository.instance;
      final created = await repo.create(
        title: 'تست CRUD',
        body: 'این یک متن تستی برای بررسی CRUD است.',
        kind: NoteKind.note,
        tags: ['پروژه', 'مهم'],
      );

      expect(created.id, startsWith('note_'));
      expect(created.title, equals('تست CRUD'));

      final fetched = await repo.getById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.body, equals('این یک متن تستی برای بررسی CRUD است.'));

      final updated = fetched.copyWith(body: 'متن جدید پس از ویرایش');
      await repo.update(updated);

      final fetchedUpdated = await repo.getById(created.id);
      expect(fetchedUpdated!.body, equals('متن جدید پس از ویرایش'));

      final counts = await repo.counts();
      expect(counts['active'], equals(1));
    });

    test('note_soft_delete_and_purge_test', () async {
      final repo = NotesRepository.instance;
      final created = await repo.create(body: 'یادداشت قابل حذف');

      await repo.delete(created.id);
      final trashed = await repo.getById(created.id);
      expect(trashed!.status, equals(NoteStatus.trashed));
      expect(trashed.trashedAt, isNotNull);

      final counts = await repo.counts();
      expect(counts['active'], equals(0));
      expect(counts['trashed'], equals(1));

      // Purge
      await repo.purge(daysOld: 0);
      final purged = await repo.getById(created.id);
      expect(purged, isNull);
    });

    test('note_revision_retention_test', () async {
      final repo = NotesRepository.instance;
      final created = await repo.create(body: 'متن اولیه اول');

      final updated1 = created.copyWith(body: 'متن ویرایش دوم با تغییرات زیاد که بیش از ۵ درصد طول متن اولیه است.');
      await repo.update(updated1);

      final revisions = await db.query('note_revisions', where: 'noteId = ?', whereArgs: [created.id]);
      expect(revisions.length, equals(1));
      expect(revisions.first['body'], equals('متن اولیه اول'));
    });

    test('note_links_unique_constraint_test', () async {
      final repo = NotesRepository.instance;
      final created = await repo.create(body: 'یادداشت با لینک');

      await repo.addLink(noteId: created.id, linkModule: 'courses', linkEntityId: 'c1', relation: 'MENTIONS');
      await repo.addLink(noteId: created.id, linkModule: 'courses', linkEntityId: 'c1', relation: 'MENTIONS');

      final links = await repo.listLinks(created.id);
      expect(links.length, equals(1));
    });

    test('experience_repository_test', () async {
      final repo = ExperienceRepository.instance;
      final exp = await repo.create(
        lesson: 'قبل از قول دادن، تقویمم را نگاه کنم.',
        contextText: 'چند بار بدقول شدم.',
        category: ExperienceCategory.work,
        importance: 5,
      );

      expect(exp.lesson, equals('قبل از قول دادن، تقویمم را نگاه کنم.'));
      expect(exp.importance, equals(5));

      final activeList = await repo.listActive();
      expect(activeList.length, equals(1));
      expect(activeList.first.noteId, equals(exp.noteId));

      await repo.recordShown(exp.noteId, '1405-05-18');
      final fetched = await repo.getByNoteId(exp.noteId);
      expect(fetched!.showCount, equals(1));
      expect(fetched.lastShownAtDayKey, equals('1405-05-18'));
    });
  });
}
