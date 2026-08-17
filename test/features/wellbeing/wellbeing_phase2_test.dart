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
  final now = DateTime(2026, 8, 17, 14, 0);

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
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
            mood TEXT,
            valence INTEGER,
            note TEXT,
            source TEXT,
            loggedAt INTEGER
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
            date TEXT,
            dimension TEXT,
            value REAL,
            note TEXT,
            source TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          );
        ''');
      },
    );
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 2 Tests — WellbeingLogGateway (B7..B14)', () {
    test('Criterion 1: logEnergy writes energy_logs with source and dual-writes to wellbeing_entry and publishes event', () async {
      final events = <RitmoEvent>[];
      final sub = RitmoEventBus().onEvents.listen(events.add);

      final id = await WellbeingLogGateway.instance.logEnergy(
        level: EnergyLevel.high,
        source: 'wellbeing_test',
        now: now,
      );

      expect(id, isNotNull);

      final energyRows = await db.query('energy_logs', where: 'id = ?', whereArgs: [id]);
      expect(energyRows.length, 1);
      expect(energyRows.first['energyLevel'], 'high');
      expect(energyRows.first['source'], 'wellbeing_test');

      final entryRows = await db.query('wellbeing_entry', where: 'id = ?', whereArgs: [id]);
      expect(entryRows.length, 1);
      expect(entryRows.first['dimension'], 'ENERGY');
      expect(entryRows.first['value'], 3.0);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events.any((e) => e.type == RitmoEventType.energyLogged.code), isTrue);

      await sub.cancel();
    });

    test('Criterion 2: logMood edits previous log within 10-minute window for QUICK_BAR', () async {
      final id1 = await WellbeingLogGateway.instance.logMood(
        score: 3,
        source: 'QUICK_BAR',
        now: now,
      );

      // Log again 5 minutes later from QUICK_BAR
      final fiveMinLater = now.add(const Duration(minutes: 5));
      final id2 = await WellbeingLogGateway.instance.logMood(
        score: 5,
        source: 'QUICK_BAR',
        now: fiveMinLater,
      );

      expect(id2, equals(id1));

      final rows = await db.query('mood_logs');
      expect(rows.length, 1);
      expect(rows.first['valence'], 5);
      expect(rows.first['mood'], 'HAPPY');
    });

    test('Criterion 3: saveReflection saves and appends to existing day, delete returns row for undo restore', () async {
      final dateStr = RitmoDate.dayKey(now);

      final id1 = await WellbeingLogGateway.instance.saveReflection(
        goodThing: 'First win',
        moodScore: 4,
        now: now,
      );
      expect(id1, isNotNull);

      // Save another reflection on same day with append
      await WellbeingLogGateway.instance.saveReflection(
        goodThing: 'Second win',
        moodScore: 5,
        now: now,
      );

      var rows = await db.query('daily_reflections', where: 'date = ?', whereArgs: [dateStr]);
      expect(rows.length, 1);
      expect(rows.first['goodThing'], contains('First win'));
      expect(rows.first['goodThing'], contains('Second win'));
      expect(rows.first['mood_score'], 5);

      // Delete reflection
      final deleted = await WellbeingLogGateway.instance.deleteReflection(dateStr);
      expect(deleted, isNotNull);
      expect(await db.query('daily_reflections'), isEmpty);

      // Restore deleted reflection
      final restored = await WellbeingLogGateway.instance.restoreReflection(deleted!);
      expect(restored, isTrue);
      rows = await db.query('daily_reflections', where: 'date = ?', whereArgs: [dateStr]);
      expect(rows.length, 1);
      expect(rows.first['goodThing'], contains('First win'));
    });
  });
}
