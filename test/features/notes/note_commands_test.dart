import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/features/notes/logic/note_commands.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('note_commands_test (T-08 to T-11)', () async {
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

      await db.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');
    });

    DatabaseHelper.databaseInstance = db;

    final context = AgentCommandContext(
      payload: {'title': 'دستور تستی', 'body': 'متن یادداشت ایجاد شده با سیستم کامند'},
      source: CommandSource.assistant,
      personaId: 'general',
      now: DateTime.now(),
      txn: db,
    );

    // 1. CreateNoteCommand
    final createCmd = CreateNoteCommand();
    final createRes = await createCmd.execute(context);
    expect(createRes.success, isTrue);
    final createdId = createRes.outputData!['id'] as String;

    // 2. SearchNotesCommand
    final searchCmd = SearchNotesCommand();
    final searchContext = AgentCommandContext(
      payload: {'query': 'سیستم کامند'},
      source: CommandSource.assistant,
      personaId: 'general',
      now: DateTime.now(),
      txn: db,
    );
    final searchRes = await searchCmd.execute(searchContext);
    expect(searchRes.success, isTrue);
    final notes = searchRes.outputData!['notes'] as List;
    expect(notes.length, equals(1));

    // 3. CreateExperienceCommand
    final createExpCmd = CreateExperienceCommand();
    final expContext = AgentCommandContext(
      payload: {'lesson': 'آموخته جدید کامند', 'importance': 5},
      source: CommandSource.assistant,
      personaId: 'general',
      now: DateTime.now(),
      txn: db,
    );
    final expRes = await createExpCmd.execute(expContext);
    expect(expRes.success, isTrue);

    await db.close();
  });
}
