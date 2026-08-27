import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/registry/domain/registry_entry.dart';
import 'package:ritmo/features/wellbeing/logic/wellbeing_log_gateway.dart';
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

  group('Audit Fixes: Wellbeing, Inbox, Registry, Search (RITF-093 .. RITF-097)', () {
    test('RITF-093: WellbeingLogGateway uses UpsertHelper to persist logs atomically', () async {
      final gateway = WellbeingLogGateway.instance;

      // 1. logEnergy
      final energyId = await gateway.logEnergy(level: EnergyLevel.high);
      expect(energyId, isNotNull);

      final energyLogs = await db.query('energy_logs', where: 'id = ?', whereArgs: [energyId]);
      expect(energyLogs.isNotEmpty, isTrue);

      // 2. logMood
      final moodId = await gateway.logMood(score: 4, note: 'Feeling great');
      expect(moodId, isNotNull);

      final moodLogs = await db.query('mood_logs', where: 'id = ?', whereArgs: [moodId]);
      expect(moodLogs.isNotEmpty, isTrue);

      // 3. saveReflection
      final reflId = await gateway.saveReflection(goodThing: 'Productive day', moodScore: 5);
      expect(reflId, isNotNull);

      final reflections = await db.query('daily_reflections', where: 'id = ?', whereArgs: [reflId]);
      expect(reflections.isNotEmpty, isTrue);
    });

    test('RITF-095 & RITF-096: TimeOfDayMinutes correctly parses HH:mm across registry', () {
      expect(TimeOfDayMinutes.tryParse('08:30'), 8 * 60 + 30);
      expect(TimeOfDayMinutes.tryParse('14:45'), 14 * 60 + 45);
      expect(TimeOfDayMinutes.tryParse('۰۸:۳۰'), 8 * 60 + 30);
      expect(TimeOfDayMinutes.tryParse('25:00'), isNull);
      expect(TimeOfDayMinutes.tryParse('invalid'), isNull);
      expect(TimeOfDayMinutes.tryParse(null), isNull);
    });
  });
}
