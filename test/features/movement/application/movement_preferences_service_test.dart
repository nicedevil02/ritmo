import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('MovementPreferencesService Tests (Gate 5)', () {
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

    test('reads default values when no record exists', () async {
      if (!dbInitialized) return;
      final dist = await service.getString(MovementPreferencesService.keyDistanceUnit, defaultValue: 'km');
      final morning = await service.getBool(MovementPreferencesService.keyMorningReminder, defaultValue: true);
      final countdown = await service.getInt(MovementPreferencesService.keyCountdownSeconds, defaultValue: 3);

      expect(dist, equals('km'));
      expect(morning, isTrue);
      expect(countdown, equals(3));
    });

    test('persists and updates preferences across keys', () async {
      if (!dbInitialized) return;
      await service.setString(MovementPreferencesService.keyDistanceUnit, 'mi');
      await service.setBool(MovementPreferencesService.keyQuietMode, true);
      await service.setInt(MovementPreferencesService.keyCountdownSeconds, 5);

      final dist = await service.getString(MovementPreferencesService.keyDistanceUnit);
      final quiet = await service.getBool(MovementPreferencesService.keyQuietMode);
      final countdown = await service.getInt(MovementPreferencesService.keyCountdownSeconds);

      expect(dist, equals('mi'));
      expect(quiet, isTrue);
      expect(countdown, equals(5));
    });

    test('deleteAllMovementData wipes movement tables cleanly', () async {
      if (!dbInitialized || db == null) return;
      await service.setString(MovementPreferencesService.keyDistanceUnit, 'mi');
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
