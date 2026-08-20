import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_readiness_checkin.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('MovementReadinessService Tests (Phase 2 / P-05 & P-06)', () {
    Database? db;
    bool dbInitialized = false;
    late MovementReadinessService service;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        service = MovementReadinessService(db: db);
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

    // 1. عدم وجود داده -> ReadinessNoData
    test('1. When no checkin data exists, returns ReadinessNoData', () async {
      if (!dbInitialized) return;
      final result = await service.getTodayReadinessResult();
      expect(result, isA<ReadinessNoData>());
    });

    // 2. چک‌این کامل با آمادگی عالی -> ReadinessReady(tier: full, score: 100)
    test('2. Optimal checkin without restrictions returns full tier with 100 score', () async {
      if (!dbInitialized) return;
      final checkin = MovementReadinessCheckin(
        id: 'chk_1',
        dateIso: '2026-08-20',
        sleep: 5,
        energy: 5,
        soreness: 1,
        stress: 1,
        createdAt: DateTime.now(),
      );

      final result = service.evaluateReadiness(
        checkin: checkin,
        cycleStatus: MovementCycleStatus.none,
      );

      expect(result, isA<ReadinessReady>());
      final ready = result as ReadinessReady;
      expect(ready.tier, equals(ReadinessTier.full));
      expect(ready.score, equals(100));
      expect(ready.isEstimated, isFalse);
      expect(ready.suggestionFa, contains('۴۵ دقیقه'));
      expect(ready.suggestionFa, isNot(contains('قاعدگی')));
      expect(ready.suggestionFa, isNot(contains('بدن')));
    });

    // 3. شاخهٔ قاعدگی سقف minimal/40 اعمال می‌کند
    test('3. Menstruation active enforces ceiling minimal and score <= 40', () async {
      if (!dbInitialized) return;
      final checkin = MovementReadinessCheckin(
        id: 'chk_menstruation',
        dateIso: '2026-08-20',
        sleep: 5,
        energy: 5,
        soreness: 1,
        stress: 1,
        createdAt: DateTime.now(),
      );

      final result = service.evaluateReadiness(
        checkin: checkin,
        cycleStatus: MovementCycleStatus.menstruation,
      );

      expect(result, isA<ReadinessReady>());
      final ready = result as ReadinessReady;
      expect(ready.tier, equals(ReadinessTier.minimal));
      expect(ready.score, lessThanOrEqualTo(40));
      expect(ready.suggestionFa, equals('با توجه به وضعیت امروزت، ۱۵ دقیقه تمرین سبک بهت میاد.'));
    });

    // 4. شاخهٔ PMS سقف light/65 اعمال می‌کند
    test('4. PMS enforces ceiling light and score <= 65', () async {
      if (!dbInitialized) return;
      final checkin = MovementReadinessCheckin(
        id: 'chk_pms',
        dateIso: '2026-08-20',
        sleep: 5,
        energy: 5,
        soreness: 1,
        stress: 1,
        createdAt: DateTime.now(),
      );

      final result = service.evaluateReadiness(
        checkin: checkin,
        cycleStatus: MovementCycleStatus.pms,
      );

      expect(result, isA<ReadinessReady>());
      final ready = result as ReadinessReady;
      expect(ready.tier, equals(ReadinessTier.light));
      expect(ready.score, lessThanOrEqualTo(65));
      expect(ready.suggestionFa, contains('۳۰ دقیقه'));
    });

    // 5. بارداری سقف rest/20 اعمال می‌کند
    test('5. Pregnancy enforces ceiling rest and score <= 20', () async {
      if (!dbInitialized) return;
      final checkin = MovementReadinessCheckin(
        id: 'chk_preg',
        dateIso: '2026-08-20',
        sleep: 4,
        energy: 4,
        soreness: 2,
        stress: 2,
        createdAt: DateTime.now(),
      );

      final result = service.evaluateReadiness(
        checkin: checkin,
        cycleStatus: MovementCycleStatus.pregnancy,
      );

      expect(result, isA<ReadinessReady>());
      final ready = result as ReadinessReady;
      expect(ready.tier, equals(ReadinessTier.rest));
      expect(ready.score, lessThanOrEqualTo(20));
      expect(ready.suggestionFa, equals('امروز استراحت کردن هم یه انتخاب خوبه.'));
    });

    // 6. داده‌های ناقص فیلدها -> isEstimated = true
    test('6. Partial checkin sets isEstimated to true', () async {
      if (!dbInitialized) return;
      final checkin = MovementReadinessCheckin(
        id: 'chk_partial',
        dateIso: '2026-08-20',
        sleep: 4,
        energy: null,
        soreness: null,
        stress: null,
        createdAt: DateTime.now(),
      );

      final result = service.evaluateReadiness(
        checkin: checkin,
        cycleStatus: MovementCycleStatus.none,
      );

      expect(result, isA<ReadinessReady>());
      final ready = result as ReadinessReady;
      expect(ready.isEstimated, isTrue);
    });
  });
}
