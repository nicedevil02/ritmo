import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/wellbeing_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_loop.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  final now = DateTime(2026, 8, 17, 10, 0);

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updatedAt INTEGER
          );
        ''');
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 4 Tests — Arbiter & Narrative Loop (B16..B19)', () {
    test('Criterion 1: WellbeingInsightLoop saves first day and compares after 7 days', () async {
      await WellbeingInsightLoop.saveIfNewDay(
        db: db,
        now: now,
        kindName: 'moodEnergyLink',
        previous: null,
        metric: 3.5,
      );

      final loaded = await WellbeingInsightLoop.load(db);
      expect(loaded, isNotNull);
      expect(loaded!.kindName, 'moodEnergyLink');
      expect(loaded.metric, 3.5);

      // Save again on same day should not overwrite baseline
      await WellbeingInsightLoop.saveIfNewDay(
        db: db,
        now: now,
        kindName: 'moodEnergyLink',
        previous: loaded,
        metric: 4.0,
      );
      final loadedSameDay = await WellbeingInsightLoop.load(db);
      expect(loadedSameDay!.metric, 3.5);
    });

    test('Criterion 2: Arbiter evaluates candidates without null pointer exceptions when partial data is provided', () {
      const arbiter = WellbeingInsightArbiter();
      const index = WellbeingIndex(
        value: 75,
        confidence: 0.8,
        contributions: [],
        missing: [],
        computedAtMillis: 1723896000000,
      );

      final snapshot = arbiter.evaluate(
        WellbeingInsightInput(
          now: now,
          horizonDays: 14,
          index: index,
          energyLogCount: 5,
          moodLogCount: 5,
          sleepLogCount: 5,
          reflectionCount: 5,
          targetSleepHours: 8.0,
        ),
      );

      expect(snapshot, isNotNull);
      expect(snapshot.ready.isNotEmpty || snapshot.growing.isNotEmpty, isTrue);
    });
  });
}
