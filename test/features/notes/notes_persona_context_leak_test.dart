import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/logic/notes_persona_context_injector.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('notes_persona_context_leak_test (V-06)', () async {
    final db = await openDatabase(inMemoryDatabasePath, version: 86, onCreate: (db, v) async {
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
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');
    });

    DatabaseHelper.databaseInstance = db;

    final repo = NotesRepository.instance;
    await repo.create(title: 'اطلاعات عمومی', body: 'کتاب خریدم');
    await repo.create(title: 'اطلاعات خصوصی', body: 'رمز پین', isPrivate: true);
    await repo.create(title: 'اطلاعات چرخه', body: 'ثبت چرخه', sourceModule: 'cycle');

    final ctxForSports = await NotesPersonaContextInjector.instance.buildContextForPersona(personaId: 'sports_coach');
    expect(ctxForSports, contains('اطلاعات عمومی'));
    expect(ctxForSports, isNot(contains('اطلاعات خصوصی')));
    expect(ctxForSports, isNot(contains('اطلاعات چرخه')));

    await db.close();
  });
}
