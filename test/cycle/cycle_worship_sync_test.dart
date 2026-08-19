import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/utils/cycle_consent_bridge.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/worship/logic/hijri_calendar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Cycle Worship & Fasting Debt Sync Tests (Phase 15)', () {
    late Database db;
    late CycleEngine engine;
    late EngineRegistry registry;

    setUp(() async {
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);

      engine = CycleEngine();
      registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. When cycle_consent_worship is enabled and period overlaps Ramadan, fasting_debt is created', () async {
      await db.insert('app_settings', {
        'key': 'cycle_consent_worship',
        'value': 'true',
        'updatedAt': 1000,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Find a Gregorian date in Ramadan (Hijri month 9)
      DateTime? ramadanDay;
      for (var d = 1; d <= 365; d++) {
        final candidate = DateTime(2026, 1, 1).add(Duration(days: d));
        final h = HijriCalendarCalculator.hijriFromGregorian(candidate);
        if (h.month == 9) {
          ramadanDay = candidate;
          break;
        }
      }
      expect(ramadanDay, isNotNull);

      // Insert period starting on ramadanDay for 5 days
      final periodStart = ramadanDay!;
      final periodEnd = periodStart.add(const Duration(days: 4));

      await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: periodStart,
        now: periodEnd,
      );
      final active = await CyclePeriodRepository.instance.getOpenPeriod(db);
      expect(active, isNotNull);

      await CyclePeriodRepository.instance.endPeriod(
        db: db,
        id: active!.id,
        endDate: periodEnd,
        now: periodEnd,
      );

      final dateStr = periodStart.toIso8601String().substring(0, 10);
      await DatabaseHelper.instance.addFastingDebtIfNeeded(db, dateStr);

      final debts = await db.query('fasting_debt');
      expect(debts.isNotEmpty, isTrue);
      expect(debts.first['daysOwed'], greaterThanOrEqualTo(1));
    });

    test('2. When cycle_consent_worship is disabled, no fasting_debt is created', () async {
      await db.insert('app_settings', {
        'key': 'cycle_consent_worship',
        'value': 'false',
        'updatedAt': 1000,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      DateTime? ramadanDay;
      for (var d = 1; d <= 365; d++) {
        final candidate = DateTime(2026, 1, 1).add(Duration(days: d));
        final h = HijriCalendarCalculator.hijriFromGregorian(candidate);
        if (h.month == 9) {
          ramadanDay = candidate;
          break;
        }
      }

      final periodStart = ramadanDay!;
      final dateStr = periodStart.toIso8601String().substring(0, 10);

      await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: periodStart,
        now: periodStart,
      );

      await DatabaseHelper.instance.addFastingDebtIfNeeded(db, dateStr);

      final debts = await db.query('fasting_debt');
      expect(debts, isEmpty);
    });

    test('3. Menstruation detection via CycleConsentBridge returns true during active period', () async {
      final now = DateTime(2026, 8, 17);
      await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: now,
        now: now,
      );

      final isMenstruating = await CycleConsentBridge.isUserMenstruating(targetDate: now);
      expect(isMenstruating, isTrue);

      final nonPeriodDay = now.add(const Duration(days: 30));
      final isMenstruatingFuture = await CycleConsentBridge.isUserMenstruating(targetDate: nonPeriodDay);
      expect(isMenstruatingFuture, isFalse);
    });
  });
}
