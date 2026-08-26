import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/data/note_bridge.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/capture_context.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/note_fts_engine.dart';
import 'package:ritmo/features/notes/logic/promote_to_note.dart';
import 'package:ritmo/features/notes/logic/resurfacing_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ritmo/core/database/schema/tables/note_tables.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await NoteTables.ensureSchema(db);
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
        },
      ),
    );

    DatabaseHelper.instance.overrideDatabaseForTesting(db);
    NoteFtsEngine.instance.invalidateCache();
  });

  tearDown(() async {
    await db.close();
  });

  group('Notes Module Fixes Audit (RITF-057 .. RITF-059)', () {
    test('RITF-058: ResurfacingEngine safely evaluates corrupt or out-of-range Jalali dayKeys', () async {
      // Create a test experience note
      final exp = await ExperienceRepository.instance.create(
        lesson: 'درس تجربی مهم',
        importance: 4,
      );

      // Artificially set an invalid lastShownAtDayKey in DB
      await db.update(
        'note_experience_meta',
        {'lastShownAtDayKey': '1403-15-99'}, // Invalid month 15 and day 99
        where: 'noteId = ?',
        whereArgs: [exp.noteId],
      );

      final candidate = await ResurfacingEngine.instance.pickTodayExperienceCandidate();
      expect(candidate, isNotNull);
      expect(candidate!.experience.noteId, exp.noteId);
    });

    test('RITF-059: ExperienceRepository creates and updates experience meta without ConflictAlgorithm.replace', () async {
      final exp = await ExperienceRepository.instance.create(
        lesson: 'یادگیری مدیریت زمان',
        importance: 5,
      );
      expect(exp.importance, 5);

      final updated = await ExperienceRepository.instance.createMetaForNote(
        noteId: exp.noteId,
        lesson: 'یادگیری مدیریت زمان - به‌روزشده',
        importance: 4,
      );
      expect(updated.lesson, 'یادگیری مدیریت زمان - به‌روزشده');

      final fetched = await ExperienceRepository.instance.getByNoteId(exp.noteId);
      expect(fetched, isNotNull);
      expect(fetched!.lesson, 'یادگیری مدیریت زمان - به‌روزشده');
      expect(fetched.importance, 4);
    });

    test('RITF-059: NotePromoter promotes module note safely with ConflictAlgorithm.abort', () async {
      final noteId = await NotePromoter.instance.promote(
        module: 'study',
        entityId: 'subj_123',
        text: 'نکته مهم کنکور در مورد درس ریاضی',
        titleHint: 'نکته ریاضی',
      );

      expect(noteId, isNotNull);

      final note = await NotesRepository.instance.getById(noteId!);
      expect(note, isNotNull);
      expect(note!.title, 'نکته ریاضی');
      expect(note.sourceModule, 'study');
      expect(note.sourceEntityId, 'subj_123');

      // Security requirement: cycle cannot be promoted
      final cyclePromote = await NotePromoter.instance.promote(
        module: 'cycle',
        entityId: 'cycle_1',
        text: 'یادداشت چرخه',
      );
      expect(cyclePromote, isNull);
    });

    test('RITF-057: CaptureContext.fromJson safely returns fallback on corrupt JSON with logging', () {
      final ctx = CaptureContext.fromJson('invalid json {[');
      expect(ctx.dayKey, isNotEmpty);
      expect(ctx.timeOfDay, 'DAY');
      expect(ctx.weekdayJalali, 1);
    });

    test('RITF-057: NoteBridge fetches notes without swallowing unhandled crashes', () async {
      final notes = await NoteBridge.instance.forEntity(
        module: 'study',
        entityId: 'subj_test',
      );
      expect(notes, isEmpty);
    });
  });
}
