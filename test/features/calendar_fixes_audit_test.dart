import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/features/calendar/data/day_mark_repository.dart';
import 'package:ritmo/features/calendar/data/day_template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await SchemaManager.createAll(db);
        },
      ),
    );

    await DatabaseHelper.ensureCriticalSchema(db);
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Calendar Module Fixes Audit (RITF-091 .. RITF-092)', () {
    test('RITF-091: DayMarkRepository uses UpsertHelper to persist marks', () async {
      final repo = DayMarkRepository(dbHelper: DatabaseHelper.instance);

      final ok1 = await repo.setMark('2026-08-27', DayMarkKind.special, note: 'Special Event');
      expect(ok1, isTrue);

      final mark1 = await repo.getMark('2026-08-27');
      expect(mark1, isNotNull);
      expect(mark1!.kind, DayMarkKind.special);
      expect(mark1.note, 'Special Event');

      // Update kind while preserving note
      final ok2 = await repo.setMark('2026-08-27', DayMarkKind.rest);
      expect(ok2, isTrue);

      final mark2 = await repo.getMark('2026-08-27');
      expect(mark2, isNotNull);
      expect(mark2!.kind, DayMarkKind.rest);
      expect(mark2.note, 'Special Event');
    });

    test('RITF-091: DayTemplateRepository uses UpsertHelper to save templates', () async {
      final repo = DayTemplateRepository(dbHelper: DatabaseHelper.instance);

      final template = DayTemplate(
        id: 'tpl_1',
        name: 'Workday Template',
        slots: const [
          DayTemplateSlot(
            title: 'Morning Deep Work',
            timeOfDay: '09:00',
            durationMinutes: 90,
          ),
        ],
        createdAt: DateTime.now(),
      );

      await repo.saveTemplate(template);

      final templates = await repo.getAllTemplates();
      expect(templates.isNotEmpty, isTrue);
      expect(templates.first.id, 'tpl_1');
      expect(templates.first.name, 'Workday Template');
      expect(templates.first.slots.length, 1);
      expect(templates.first.slots.first.title, 'Morning Deep Work');
    });
  });
}
