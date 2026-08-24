import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/wellbeing/logic/wellbeing_log_gateway.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  final now = DateTime(2026, 8, 17, 15, 0);

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE bedtime_diagnostics (
            date TEXT PRIMARY KEY,
            reason TEXT NOT NULL,
            note TEXT,
            createdAt INTEGER NOT NULL,
            bedtimeAt INTEGER,
            wakeAt INTEGER,
            durationMinutes INTEGER,
            quality INTEGER NOT NULL DEFAULT 3,
            awakenings INTEGER NOT NULL DEFAULT 0
          );
        ''');
        await d.execute('''
          CREATE TABLE energy_logs (
            id TEXT PRIMARY KEY,
            level INTEGER,
            energyLevel TEXT,
            source TEXT,
            loggedAt INTEGER,
            createdAt INTEGER
          );
        ''');
        await d.execute('''
          CREATE TABLE mood_logs (
            id TEXT PRIMARY KEY,
            mood TEXT NOT NULL,
            valence INTEGER NOT NULL DEFAULT 3,
            note TEXT,
            loggedAt INTEGER NOT NULL
          );
        ''');
        await d.execute('''
          CREATE TABLE daily_reflections (
            id TEXT PRIMARY KEY,
            date TEXT,
            goodThing TEXT,
            wins TEXT,
            mood_score INTEGER,
            reflection_text TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          );
        ''');
        await d.execute('''
          CREATE TABLE wellbeing_entry (
            id TEXT PRIMARY KEY,
            dateIso TEXT NOT NULL,
            dimension TEXT NOT NULL,
            value REAL NOT NULL,
            note TEXT,
            loggedAt INTEGER NOT NULL
          );
        ''');
      },
    );
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 3 Tests — DB Unification & Dual-Write (B15)', () {
    test('Criterion 1: logSleep dual-writes to bedtime_diagnostics and wellbeing_entry (SLEEP)', () async {
      final events = <RitmoEvent>[];
      final sub = RitmoEventBus().onEvents.listen(events.add);

      final dateStr = RitmoDate.dayKey(now);
      final id = await WellbeingLogGateway.instance.logSleep(
        date: dateStr,
        durationMinutes: 480,
        quality: 4,
        note: 'Good deep rest',
        now: now,
      );

      expect(id, isNotNull);

      final sleepRows = await db.query('bedtime_diagnostics', where: 'date = ?', whereArgs: [dateStr]);
      expect(sleepRows.length, 1);
      expect(sleepRows.first['durationMinutes'], 480);
      expect(sleepRows.first['quality'], 4);

      final entryRows = await db.query('wellbeing_entry', where: 'id = ?', whereArgs: [id]);
      expect(entryRows.length, 1);
      expect(entryRows.first['dimension'], 'SLEEP');
      expect(entryRows.first['value'], 4.0);
      expect(entryRows.first['dateIso'], dateStr);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events.any((e) => e.type == RitmoEventType.sleepLogged.code), isTrue);

      await sub.cancel();
    });

    test('Criterion 2: All 4 dimensions dual-write cleanly into wellbeing_entry', () async {
      final dateStr = RitmoDate.dayKey(now);

      await WellbeingLogGateway.instance.logEnergy(level: EnergyLevel.medium, now: now);
      await WellbeingLogGateway.instance.logMood(score: 4, now: now);
      await WellbeingLogGateway.instance.logSleep(date: dateStr, durationMinutes: 450, quality: 3, now: now);
      await WellbeingLogGateway.instance.saveReflection(goodThing: 'Great milestone', moodScore: 5, now: now);

      final entries = await db.query('wellbeing_entry');
      expect(entries.length, 4);

      final dimensions = entries.map((e) => e['dimension']).toSet();
      expect(dimensions, containsAll(['ENERGY', 'MOOD', 'SLEEP', 'REFLECTION']));
    });
  });
}
