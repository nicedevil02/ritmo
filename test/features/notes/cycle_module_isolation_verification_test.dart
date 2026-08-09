import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/notes/logic/promote_to_note.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('cycle_module_isolation_verification_test (V-04)', () async {
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
    });

    DatabaseHelper.databaseInstance = db;

    // Promotion MUST be blocked for cycle module (Decision 7)
    final result = await NotePromoter.instance.promote(
      context: null,
      module: 'cycle',
      entityId: 'c1',
      text: 'نوت چرخه',
    );

    expect(result, isNull);

    final notes = await db.query('notes');
    expect(notes, isEmpty);

    await db.close();
  });
}
