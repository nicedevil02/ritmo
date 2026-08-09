import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/logic/resurfacing_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('resurfacing_engine_test (R-05)', () async {
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
    });

    DatabaseHelper.databaseInstance = db;

    final repo = ExperienceRepository.instance;
    await repo.create(lesson: 'تجربه ۱ کم‌اهمیت', importance: 1);
    final topExp = await repo.create(lesson: 'تجربه ۲ بسیار مهم', importance: 5);
    await repo.create(lesson: 'تجربه ۳ متوسط', importance: 3);

    final candidate = await ResurfacingEngine.instance.pickTodayExperienceCandidate();
    expect(candidate, isNotNull);
    expect(candidate!.experience.noteId, equals(topExp.noteId));

    await db.close();
  });
}
