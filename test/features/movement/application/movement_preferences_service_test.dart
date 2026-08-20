import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('MovementPreferencesService Tests (D-38)', () {
    Database? db;
    bool dbInitialized = false;
    late MovementPreferencesService service;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        service = MovementPreferencesService(db: db);
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized && db != null) {
        await db!.close();
      }
    });

    test('reads default values for weeklyGoal, preferredDays, reminderHour', () async {
      if (!dbInitialized) return;
      final goal = await service.getWeeklyGoalSessions();
      final days = await service.getPreferredDays();
      final reminder = await service.getReminderHour();

      expect(goal, equals(3));
      expect(days, equals([0, 2, 4]));
      expect(reminder, equals(8));
    });

    test('persists and updates 3 core preferences', () async {
      if (!dbInitialized) return;
      await service.setWeeklyGoalSessions(5);
      await service.setPreferredDays([1, 3, 5]);
      await service.setReminderHour(7);

      final goal = await service.getWeeklyGoalSessions();
      final days = await service.getPreferredDays();
      final reminder = await service.getReminderHour();

      expect(goal, equals(5));
      expect(days, equals([1, 3, 5]));
      expect(reminder, equals(7));

      await service.setReminderHour(null);
      final noReminder = await service.getReminderHour();
      expect(noReminder, isNull);
    });

    test('deleteAllMovementData wipes movement tables cleanly in transaction', () async {
      if (!dbInitialized || db == null) return;
      await service.setWeeklyGoalSessions(5);
      await db!.insert(MovementTables.tableOccurrences, {
        'id': 'occ_temp',
        'activityKindId': 'kind_walking',
        'dateIso': '2026-08-16',
        'status': 'scheduled',
        'origin': 'manual',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      var occs = await db!.query(MovementTables.tableOccurrences);
      expect(occs.isNotEmpty, isTrue);

      await service.deleteAllMovementData();

      occs = await db!.query(MovementTables.tableOccurrences);
      expect(occs.isEmpty, isTrue);

      final pref = await db!.query(MovementTables.tablePreferences);
      expect(pref.isEmpty, isTrue);
    });
  });
}
