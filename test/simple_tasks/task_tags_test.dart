import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/utils/persian_text.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_step_repository.dart';
import 'package:ritmo/features/simple_tasks/logic/task_tag_parser.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE simple_tasks (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              titleNormalized TEXT,
              note TEXT,
              noteNormalized TEXT,
              tagsJson TEXT,
              isDone INTEGER NOT NULL DEFAULT 0,
              doneAt INTEGER,
              dueDate TEXT,
              dueTime TEXT,
              reminderAtMs INTEGER,
              reminderId TEXT,
              linkedRoutineId TEXT,
              orderIndex INTEGER NOT NULL DEFAULT 0,
              origin TEXT NOT NULL DEFAULT 'SIMPLE',
              isImportant INTEGER NOT NULL DEFAULT 0,
              importantAt INTEGER,
              addedToMyDayAt INTEGER,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE task_steps (
              id TEXT PRIMARY KEY,
              taskId TEXT NOT NULL,
              title TEXT NOT NULL,
              titleNormalized TEXT,
              isCompleted INTEGER NOT NULL DEFAULT 0,
              displayOrder INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL,
              completedAt INTEGER
            );
          ''');
          await db.execute('''
            CREATE TABLE task_attachments (
              id TEXT PRIMARY KEY,
              taskId TEXT NOT NULL,
              fileName TEXT NOT NULL,
              fileSizeBytes INTEGER NOT NULL DEFAULT 0,
              mimeType TEXT,
              localPath TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            );
          ''');
        },
      ),
    );
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TaskTagParser & Hashtag Extraction', () {
    test('1. "#کتاب خریدن" parses cleanTitle "خریدن" and tag "کتاب"', () {
      final parsed = parseTags('#کتاب خریدن');
      expect(parsed.cleanTitle, equals('خریدن'));
      expect(parsed.tags, equals(['کتاب']));
    });

    test('2. Title with 4 tags extracts exactly 3 tags and 4th remains in cleanTitle', () {
      final parsed = parseTags('خریدن #کتاب #درس #کار #ورزش');
      expect(parsed.tags.length, equals(3));
      expect(parsed.tags, equals(['کتاب', 'درس', 'کار']));
      expect(parsed.cleanTitle, equals('خریدن #ورزش'));
    });

    test('3. Standalone hashtag does not create a tag', () {
      final parsed = parseTags('خریدن # کتاب # ');
      expect(parsed.tags, isEmpty);
      expect(parsed.cleanTitle, equals('خریدن # کتاب #'));
    });

    test('4. Two spellings of a tag (Persian and Arabic Yeh/Kaf) normalize to identical string', () {
      final parsedPersian = parseTags('#کتاب خرید');
      final parsedArabic = parseTags('#كتاب خرید'); // Arabic kaf \u0643
      expect(parsedPersian.tags.first, equals(parsedArabic.tags.first));
    });

    test('5. Title containing only tags does not produce empty task title', () {
      final parsed = parseTags('#کار');
      expect(parsed.cleanTitle, equals('#کار'));
      expect(parsed.tags, isEmpty);
    });
  });

  group('Search Engine Normalization parity', () {
    test('6. Search finds task where keyword is only in note in Arabic spelling (T-22 bug fix)', () async {
      // Note contains Arabic Kaf & Yeh: "تطبيق كتاب"
      final noteWithArabic = 'تطبيق كتاب عربي';
      final task = await SimpleTaskRepository.instance.create(
        title: 'Task 1',
        note: noteWithArabic,
      );

      // Search using Persian text: "تطبیق" / "عربی"
      final results1 = await SimpleTaskRepository.instance.search('تطبیق');
      final results2 = await SimpleTaskRepository.instance.search('عربی');

      expect(results1.map((t) => t.id), contains(task.id));
      expect(results2.map((t) => t.id), contains(task.id));
    });

    test('7. Search finds task matching keyword in a sub-step title', () async {
      final task = await SimpleTaskRepository.instance.create(title: 'Parent Task');
      await TaskStepRepository.instance.add(
        taskId: task.id,
        title: 'مرحله آزمایشی مهم',
      );

      final results = await SimpleTaskRepository.instance.search('آزمایشی');
      expect(results.map((t) => t.id), contains(task.id));
    });
  });
}
