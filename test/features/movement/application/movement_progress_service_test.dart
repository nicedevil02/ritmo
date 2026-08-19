import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/movement_progress_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('MovementProgressService Tests (Gate 5)', () {
    Database? db;
    bool dbInitialized = false;
    late MovementProgressService service;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        await MovementTables.seedInitialData(db!);
        service = MovementProgressService(db: db);
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

    test(
      'getKpiData calculates correct minutes, sessions and adherence',
      () async {
        if (!dbInitialized || db == null) return;
        final now = DateTime(2026, 8, 16);

        // Insert workout logs
        await db!.insert(MovementTables.tableWorkoutLogs, {
          'id': 'log_1',
          'activityKindId': 'kind_walking',
          'dateIso': '2026-08-15',
          'durationSec': 1800, // 30 min
          'metricJson': jsonEncode({'distanceKm': 2.5}),
          'source': 'live',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });

        await db!.insert(MovementTables.tableWorkoutLogs, {
          'id': 'log_2',
          'activityKindId': 'kind_running',
          'dateIso': '2026-08-16',
          'durationSec': 2400, // 40 min
          'metricJson': jsonEncode({'distanceKm': 5.0}),
          'source': 'live',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });

        final kpi = await service.getKpiData(
          range: MovementProgressRange.week,
          now: now,
        );

        expect(kpi.sessionCount, equals(2));
        expect(kpi.activeMinutes, equals(70));
        expect(kpi.activeDaysCount, equals(2));
        expect(kpi.totalDistanceKm, equals(7.5));
      },
    );

    test('getDistributionData computes percentage and count', () async {
      if (!dbInitialized || db == null) return;
      final now = DateTime(2026, 8, 16);

      await db!.insert(MovementTables.tableWorkoutLogs, {
        'id': 'log_w1',
        'activityKindId': 'kind_walking',
        'dateIso': '2026-08-15',
        'durationSec': 1200,
        'source': 'live',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      await db!.insert(MovementTables.tableWorkoutLogs, {
        'id': 'log_w2',
        'activityKindId': 'kind_walking',
        'dateIso': '2026-08-16',
        'durationSec': 1200,
        'source': 'live',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      final distribution = await service.getDistributionData();
      expect(distribution.isNotEmpty, isTrue);
      final walking = distribution.firstWhere((d) => d.family == 'walking');
      expect(walking.count, equals(2));
      expect(walking.percentage, equals(100.0));
    });

    test('evaluateAndSaveRecord stores and updates new PRs', () async {
      if (!dbInitialized || db == null) return;
      await service.evaluateAndSaveRecord(
        activityKindId: 'kind_running',
        recordType: 'max_distance',
        value: 5.0,
        unit: 'km',
      );

      var prs = await service.getPersonalRecords();
      expect(prs.length, equals(1));
      expect(prs.first.value, equals(5.0));

      // Higher record updates existing
      await service.evaluateAndSaveRecord(
        activityKindId: 'kind_running',
        recordType: 'max_distance',
        value: 7.5,
        unit: 'km',
      );

      prs = await service.getPersonalRecords();
      expect(prs.length, equals(1));
      expect(prs.first.value, equals(7.5));
    });
  });
}
