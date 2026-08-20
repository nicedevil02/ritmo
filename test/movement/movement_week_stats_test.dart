import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_stats.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('MovementWeekStats & Tier Resolution Tests (Phase 1)', () {
    Database? db;
    bool dbInitialized = false;
    late MovementOccurrenceService occService;
    late MovementPreferencesService prefService;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        occService = MovementOccurrenceService(db: db);
        prefService = MovementPreferencesService(db: db);
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

    // 1. هفتهٔ کاملاً خالی
    test('1. Empty week returns hasAnyData false and adherence noData', () async {
      if (!dbInitialized) return;
      final anchor = DateTime(2026, 8, 20); // پنجشنبه
      final stats = await occService.weekStats(anchor);

      expect(stats.hasAnyData, isFalse);
      expect(stats.plannedCount, equals(0));
      expect(stats.doneCount, equals(0));
      expect(stats.totalMinutes, equals(0));
      expect(stats.adherence.reason, equals(MovementMetricReason.noData));
      expect(stats.adherence.value, isNull);
      expect(stats.weekContractLabel(), equals(''));
    });

    // 2. هفته با تعداد برنامه‌ریزی کمتر از ۴ (sampleSize < 4)
    test('2. Week with sampleSize < 4 returns partialData adherence', () async {
      if (!dbInitialized || db == null) return;
      final anchor = DateTime(2026, 8, 20);
      final sat = DateTime(2026, 8, 15); // شنبه

      for (int i = 0; i < 3; i++) {
        final dateIso = sat.add(Duration(days: i * 2)).toIso8601String().split('T').first;
        await db!.insert(MovementTables.tableOccurrences, {
          'id': 'occ_test_$i',
          'activityKindId': 'kind_walking',
          'dateIso': dateIso,
          'status': i < 2 ? 'completed' : 'scheduled',
          'origin': 'manual',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      final stats = await occService.weekStats(anchor);

      expect(stats.hasAnyData, isTrue);
      expect(stats.plannedCount, equals(3));
      expect(stats.doneCount, equals(2));
      expect(stats.adherence.sampleSize, equals(3));
      expect(stats.adherence.reason, equals(MovementMetricReason.partialData));
      expect(stats.adherence.value, isNull);
      expect(stats.weekContractLabel(), equals('این هفته: ۲ از ۳'));
    });

    // 3. هفته با پایبندی کامل (sampleSize >= 4)
    test('3. Full week with sampleSize >= 4 returns ok adherence 1.0 and celebration label', () async {
      if (!dbInitialized || db == null) return;
      final anchor = DateTime(2026, 8, 20);
      final sat = DateTime(2026, 8, 15);

      for (int i = 0; i < 5; i++) {
        final dateIso = sat.add(Duration(days: i)).toIso8601String().split('T').first;
        await db!.insert(MovementTables.tableOccurrences, {
          'id': 'occ_full_$i',
          'activityKindId': 'kind_running',
          'dateIso': dateIso,
          'status': 'completed',
          'origin': 'manual',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
        await db!.insert(MovementTables.tableWorkoutLogs, {
          'id': 'log_full_$i',
          'occurrenceId': 'occ_full_$i',
          'activityKindId': 'kind_running',
          'dateIso': dateIso,
          'durationSec': 1800, // 30 mins
          'source': 'live',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      final stats = await occService.weekStats(anchor);

      expect(stats.hasAnyData, isTrue);
      expect(stats.plannedCount, equals(5));
      expect(stats.doneCount, equals(5));
      expect(stats.totalMinutes, equals(150));
      expect(stats.adherence.reason, equals(MovementMetricReason.ok));
      expect(stats.adherence.value, equals(1.0));
      expect(stats.weekContractLabel(), equals('هفته‌ات کامله 🎉'));
    });

    // 4. هفته با پایبندی جزئی و sampleSize >= 4
    test('4. Partial completion with sampleSize >= 4 calculates accurate adherence', () async {
      if (!dbInitialized || db == null) return;
      final anchor = DateTime(2026, 8, 20);
      final sat = DateTime(2026, 8, 15);

      for (int i = 0; i < 4; i++) {
        final dateIso = sat.add(Duration(days: i)).toIso8601String().split('T').first;
        await db!.insert(MovementTables.tableOccurrences, {
          'id': 'occ_part_$i',
          'activityKindId': 'kind_swimming',
          'dateIso': dateIso,
          'status': i < 3 ? 'completed' : 'scheduled',
          'origin': 'manual',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      final stats = await occService.weekStats(anchor);

      expect(stats.plannedCount, equals(4));
      expect(stats.doneCount, equals(3));
      expect(stats.adherence.reason, equals(MovementMetricReason.ok));
      expect(stats.adherence.value, equals(0.75));
      expect(stats.weekContractLabel(), equals('این هفته: ۳ از ۴'));
    });

    // 5. ثبت آزاد بدون برنامه قبلی
    test('5. Retro workouts without planned occurrences calculate total minutes correctly', () async {
      if (!dbInitialized || db == null) return;
      final anchor = DateTime(2026, 8, 20);
      final sat = DateTime(2026, 8, 15);

      await db!.insert(MovementTables.tableWorkoutLogs, {
        'id': 'log_retro_1',
        'occurrenceId': null,
        'activityKindId': 'kind_cycling',
        'dateIso': sat.toIso8601String().split('T').first,
        'durationSec': 2400, // 40 mins
        'source': 'retro',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final stats = await occService.weekStats(anchor);

      expect(stats.hasAnyData, isTrue);
      expect(stats.plannedCount, equals(0));
      expect(stats.doneCount, equals(1));
      expect(stats.totalMinutes, equals(40));
      expect(stats.adherence.reason, equals(MovementMetricReason.noData));
    });

    // 6. تست‌های Tier Resolution (P-01 & P-02)
    test('6. Tier resolution locks Tier 2/3 until 6 completed sessions', () async {
      if (!dbInitialized || db == null) return;

      expect(await prefService.resolveTier(), equals(MovementTier.one));

      await prefService.setTier(MovementTier.two);
      // هنوز ۶ جلسه ثبت نشده، پس باید tier 1 برگردد
      expect(await prefService.resolveTier(), equals(MovementTier.one));

      // ثبت ۶ جلسهٔ ورزشی
      for (int i = 0; i < 6; i++) {
        await db!.insert(MovementTables.tableWorkoutLogs, {
          'id': 'log_unlock_$i',
          'activityKindId': 'kind_walking',
          'dateIso': '2026-08-${(10 + i).toString().padLeft(2, '0')}',
          'durationSec': 1200,
          'source': 'live',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // اکنون Tier 2 آزاد شده است
      expect(await prefService.resolveTier(), equals(MovementTier.two));

      await prefService.setTier(MovementTier.three);
      expect(await prefService.resolveTier(), equals(MovementTier.three));
    });
  });
}
