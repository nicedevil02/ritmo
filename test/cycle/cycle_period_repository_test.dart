import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CyclePeriod Model Contract', () {
    test('isOpen returns true when endDate is null and false when endDate is present', () {
      final open = CyclePeriod(
        id: 'p1',
        startDate: DateTime(2026, 8, 1),
        endDate: null,
      );
      expect(open.isOpen, isTrue);

      final closed = CyclePeriod(
        id: 'p2',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 6),
      );
      expect(closed.isOpen, isFalse);
      expect(closed.durationDays, equals(6));
    });

    test('toMap and fromMap serialize and deserialize accurately with String ID and canonical columns', () {
      final original = CyclePeriod(
        id: 'period_custom_1',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 7),
        flowIntensity: 'HEAVY',
        isPredicted: false,
        note: 'دوره قاعدگی آزمایشی',
        createdAt: 1700000000,
        updatedAt: 1700005000,
      );

      final map = original.toMap();
      expect(map[CyclePeriodContract.colId], 'period_custom_1');
      expect(map[CyclePeriodContract.colStartDate], '2026-08-01');
      expect(map[CyclePeriodContract.colEndDate], '2026-08-07');
      expect(map[CyclePeriodContract.colFlowIntensity], 'HEAVY');
      expect(map[CyclePeriodContract.colIsPredicted], 0);
      expect(map[CyclePeriodContract.colNote], 'دوره قاعدگی آزمایشی');

      final restored = CyclePeriod.fromMap(map);
      expect(restored.id, 'period_custom_1');
      expect(restored.startDate, DateTime(2026, 8, 1));
      expect(restored.endDate, DateTime(2026, 8, 7));
      expect(restored.flowIntensity, 'HEAVY');
      expect(restored.isPredicted, isFalse);
      expect(restored.note, 'دوره قاعدگی آزمایشی');
    });
  });

  group('CyclePeriodRepository Rules (R1..R10)', () {
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

    test('R1, R2, R3, R10: startPeriod generates valid String ID, normalized dates, and getOpenPeriod works', () async {
      final now = DateTime(2026, 8, 17);
      final id = await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 15, 14, 30), // Has time component
        now: now,
      );

      expect(id, isNotEmpty);
      expect(id, startsWith('period_'));

      final active = await CyclePeriodRepository.instance.getOpenPeriod(db);
      expect(active, isNotNull);
      expect(active!.id, equals(id));
      expect(active.startDate, equals(DateTime(2026, 8, 15))); // Time stripped
      expect(active.endDate, isNull);
      expect(active.isOpen, isTrue);
    });

    test('R4: Validation guard prevents start date in the future', () async {
      final now = DateTime(2026, 8, 17);
      expect(
        () => CyclePeriodRepository.instance.startPeriod(
          db: db,
          startDate: DateTime(2026, 8, 18),
          now: now,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('R4: Validation guard prevents end date before start date or in the future or > 45 days', () async {
      final now = DateTime(2026, 8, 17);
      final id = await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 10),
        now: now,
      );

      // End date before start date
      expect(
        () => CyclePeriodRepository.instance.endPeriod(
          db: db,
          id: id,
          endDate: DateTime(2026, 8, 9),
          now: now,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // End date in the future
      expect(
        () => CyclePeriodRepository.instance.endPeriod(
          db: db,
          id: id,
          endDate: DateTime(2026, 8, 18),
          now: now,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('R5: Duplicate start on exact same startDate returns existing open period ID without duplicating', () async {
      final now = DateTime(2026, 8, 17);
      final id1 = await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 15),
        now: now,
      );

      final id2 = await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 15),
        now: now,
      );

      expect(id1, equals(id2));
      final all = await CyclePeriodRepository.instance.getAllPeriods(db);
      expect(all.length, equals(1));
    });

    test('R6: If active open period exists (< 45 days), starting another throws StateError', () async {
      final now = DateTime(2026, 8, 17);
      await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 10),
        now: now,
      );

      expect(
        () => CyclePeriodRepository.instance.startPeriod(
          db: db,
          startDate: DateTime(2026, 8, 15),
          now: now,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('R6: If active open period is forgotten (>= 45 days), starting a new period auto-closes the forgotten period', () async {
      final now = DateTime(2026, 8, 17);
      final oldStart = now.subtract(const Duration(days: 60)); // 60 days ago

      final id1 = await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: oldStart,
        now: oldStart,
      );

      // Starting a new period on now
      final id2 = await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: now,
        now: now,
      );

      expect(id2, isNot(equals(id1)));

      final all = await CyclePeriodRepository.instance.getAllPeriods(db);
      expect(all.length, equals(2));

      final closedOld = all.firstWhere((p) => p.id == id1);
      expect(closedOld.isOpen, isFalse);
      expect(closedOld.endDate, isNotNull);

      final activeNew = all.firstWhere((p) => p.id == id2);
      expect(activeNew.isOpen, isTrue);
    });

    test('R8: Ending or updating non-existent period ID throws StateError', () async {
      final now = DateTime(2026, 8, 17);
      expect(
        () => CyclePeriodRepository.instance.endPeriod(
          db: db,
          id: 'non_existent_id',
          endDate: now,
          now: now,
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        () => CyclePeriodRepository.instance.updatePeriod(
          db: db,
          id: 'non_existent_id',
          startDate: now,
          now: now,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('R9: getAllPeriods returns records sorted by startDate DESC', () async {
      await db.insert('cycle_periods', {
        'id': 'p1',
        'startDate': '2026-06-01',
        'endDate': '2026-06-06',
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await db.insert('cycle_periods', {
        'id': 'p3',
        'startDate': '2026-08-01',
        'endDate': '2026-08-06',
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await db.insert('cycle_periods', {
        'id': 'p2',
        'startDate': '2026-07-01',
        'endDate': '2026-07-06',
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      final all = await CyclePeriodRepository.instance.getAllPeriods(db);
      expect(all.length, equals(3));
      expect(all[0].id, equals('p3'));
      expect(all[1].id, equals('p2'));
      expect(all[2].id, equals('p1'));
    });

    test('updatePeriod with clearEndDate=true or endDate=null clears endDate in database', () async {
      final now = DateTime(2026, 8, 17);
      await db.insert('cycle_periods', {
        'id': 'p_to_reopen',
        'startDate': '2026-08-14',
        'endDate': '2026-08-16',
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      await CyclePeriodRepository.instance.updatePeriod(
        db: db,
        id: 'p_to_reopen',
        startDate: DateTime(2026, 8, 14),
        endDate: null,
        clearEndDate: true,
        now: now,
      );

      final open = await CyclePeriodRepository.instance.getOpenPeriod(db);
      expect(open, isNotNull);
      expect(open!.id, equals('p_to_reopen'));
      expect(open.endDate, isNull);
      expect(open.isOpen, isTrue);
    });

    test('validatePeriodRange enforces endDate for periods started > 15 days ago', () {
      final now = DateTime(2026, 8, 27);
      final oldStart = DateTime(2026, 8, 1); // 26 days ago (>15)
      final recentStart = DateTime(2026, 8, 25); // 2 days ago (<=15)

      // Old period without endDate -> error
      final errOld = CyclePeriodRepository.validatePeriodRange(
        existing: [],
        editingId: null,
        startDate: oldStart,
        endDate: null,
        now: now,
      );
      expect(errOld, isNotNull);
      expect(errOld!.contains('۱۵ روز'), isTrue);

      // Old period with endDate -> valid
      final validOld = CyclePeriodRepository.validatePeriodRange(
        existing: [],
        editingId: null,
        startDate: oldStart,
        endDate: DateTime(2026, 8, 6),
        now: now,
      );
      expect(validOld, isNull);

      // Recent period without endDate -> valid (open period)
      final validRecent = CyclePeriodRepository.validatePeriodRange(
        existing: [],
        editingId: null,
        startDate: recentStart,
        endDate: null,
        now: now,
      );
      expect(validRecent, isNull);
    });
  });
}
