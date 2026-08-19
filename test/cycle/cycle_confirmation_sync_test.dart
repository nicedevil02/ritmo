import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/features/cycle/logic/cycle_confirmation_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Cycle Confirmation Sync Tests (Phase 10)', () {
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

    test('1. startPeriod clears startDue confirmations and snoozeUntil setting', () async {
      final now = DateTime(2026, 8, 17);
      final nowMs = now.millisecondsSinceEpoch;

      // Seed a startDue confirmation request and a snoozeUntil setting
      await db.insert('cycle_confirmations', {
        'id': 'startDue_2026-08-17',
        'kind': 'startDue',
        'targetDate': '2026-08-17',
        'askCount': 1,
        'createdAt': nowMs,
        'updatedAt': nowMs,
      });

      await db.insert('app_settings', {
        'key': CycleSettings.keyConfirmSnoozeUntil,
        'value': '2026-08-18',
        'updatedAt': nowMs,
      });

      // Start period
      await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 17),
        now: now,
      );

      // Verify startDue is deleted
      final confirmations = await db.query(
        'cycle_confirmations',
        where: "kind = 'startDue'",
      );
      expect(confirmations, isEmpty);

      // Verify snooze setting is deleted
      final settings = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [CycleSettings.keyConfirmSnoozeUntil],
      );
      expect(settings, isEmpty);
    });

    test('2. endPeriod clears endDue and bleedingProlonged confirmations', () async {
      final now = DateTime(2026, 8, 17);
      final nowMs = now.millisecondsSinceEpoch;

      final id = await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 10),
        now: now,
      );

      // Seed endDue and bleedingProlonged confirmation requests
      await db.insert('cycle_confirmations', {
        'id': 'endDue_2026-08-16',
        'kind': 'endDue',
        'targetDate': '2026-08-16',
        'askCount': 1,
        'createdAt': nowMs,
        'updatedAt': nowMs,
      });
      await db.insert('cycle_confirmations', {
        'id': 'bleedingProlonged_2026-08-10',
        'kind': 'bleedingProlonged',
        'targetDate': '2026-08-10',
        'askCount': 2,
        'createdAt': nowMs,
        'updatedAt': nowMs,
      });

      // End period
      await CyclePeriodRepository.instance.endPeriod(
        db: db,
        id: id,
        endDate: DateTime(2026, 8, 16),
        now: now,
      );

      // Verify endDue & bleedingProlonged are cleared
      final remaining = await db.query(
        'cycle_confirmations',
        where: "kind IN ('endDue', 'bleedingProlonged')",
      );
      expect(remaining, isEmpty);
    });

    test('3. pruneOldRequests deletes confirmations older than 90 days', () async {
      final now = DateTime(2026, 8, 17);
      final oldDate = now.subtract(const Duration(days: 100));
      final recentDate = now.subtract(const Duration(days: 30));

      await db.insert('cycle_confirmations', {
        'id': 'old_req',
        'kind': 'startDue',
        'targetDate': CycleDateContract.toDayKey(oldDate),
        'askCount': 1,
        'createdAt': oldDate.millisecondsSinceEpoch,
        'updatedAt': oldDate.millisecondsSinceEpoch,
      });

      await db.insert('cycle_confirmations', {
        'id': 'recent_req',
        'kind': 'startDue',
        'targetDate': CycleDateContract.toDayKey(recentDate),
        'askCount': 1,
        'createdAt': recentDate.millisecondsSinceEpoch,
        'updatedAt': recentDate.millisecondsSinceEpoch,
      });

      await CycleConfirmationService.instance.pruneOldRequests(
        dbExecutor: db,
        now: now,
      );

      final rows = await db.query('cycle_confirmations');
      expect(rows.length, equals(1));
      expect(rows.first['id'], equals('recent_req'));
    });
  });
}
