import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('PregnancyOnboarding Atomic Save Tests (PRG-23)', () {
    late Database db;
    late CycleEngine engine;
    late EngineRegistry registry;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      await CycleLockService.instance.setLockEnabled(false, db);
      await CycleLockService.instance.clearPin(db);

      engine = CycleEngine();
      registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'saves all onboarding fields atomically and closes open periods',
      () async {
        final now = CycleClock.now;
        final lmp = CycleDateContract.cleanDate(
          now.subtract(const Duration(days: 70)),
        );
        final due = PregnancyDateEngine.dueDateFromLmp(lmp);

        // Insert an open period into cycle_periods
        final openPeriodStart = CycleDateContract.cleanDate(
          now.subtract(const Duration(days: 80)),
        );
        await db.insert(CyclePeriodContract.table, {
          CyclePeriodContract.colId: 'test_open_period',
          CyclePeriodContract.colStartDate: CycleDateContract.toDayKey(
            openPeriodStart,
          ),
          CyclePeriodContract.colEndDate: null,
          CyclePeriodContract.colFlowIntensity: 'MEDIUM',
          CyclePeriodContract.colIsPredicted: 0,
          CyclePeriodContract.colCreatedAt:
              CycleClock.nowMillisecondsSinceEpoch,
          CyclePeriodContract.colUpdatedAt:
              CycleClock.nowMillisecondsSinceEpoch,
        });

        final controller = PregnancyOnboardingController();
        final data = PregnancyOnboardingData(
          tone: PregnancyTone.neutral,
          eddSource: PregnancyEddSource.lmp,
          lmpDate: lmp,
          dueDate: due,
          isMultiple: true,
          isHighRisk: true,
          pauseCyclePredictions: true,
          suspendWorship: true,
          lockEnabled: true,
          hideFromDashboard: true,
          maskNotifications: true,
          ageUnit: PregnancyAgeUnit.months,
        );

        await controller.savePregnancyOnboarding(data, db: db);

        // Verify settings in app_settings
        final rawSettings = await db.query('app_settings');
        final settings = {
          for (final row in rawSettings) row['key'] as String: row['value'],
        };

        expect(settings['preg_tone'], 'neutral');
        expect(settings['preg_edd_source'], 'lmp');
        expect(settings['preg_start_date'], CycleDateContract.toDayKey(lmp));
        expect(settings['preg_due_date'], CycleDateContract.toDayKey(due));
        expect(settings['preg_is_multiple'], 'true');
        expect(settings['preg_is_high_risk'], 'true');
        expect(settings['preg_lock_enabled'], 'true');
        expect(settings['preg_section_hidden'], 'true');
        expect(settings['preg_mask_notifications'], 'true');
        expect(settings['preg_age_unit'], 'months');
        expect(settings['preg_setup_done'], 'true');

        // Flags
        expect(settings['cycle_pregnancy_mode'], 'true');
        expect(settings['pregnancy_mode'], 'true');
        expect(settings['cycle_is_pregnant'], 'true');

        // Privacy consents updated
        expect(settings['cycle_consent_reminders'], 'false');
        expect(settings['cycle_consent_worship'], 'false');
        expect(settings['cycle_consent_dashboard'], 'false');

        // Open period closed
        final closedRows = await db.query(
          CyclePeriodContract.table,
          where: '${CyclePeriodContract.colId} = ?',
          whereArgs: ['test_open_period'],
        );
        expect(closedRows.first[CyclePeriodContract.colEndDate], isNotNull);
      },
    );

    test(
      'atomic transaction rolls back completely on error without leaving partial state',
      () async {
        try {
          await db.transaction((txn) async {
            await PregnancySettings.saveSetting(
              'test_marker',
              'marker_val',
              txn,
            );
            throw Exception('Simulated failure during save');
          });
        } catch (_) {
          // Exception properly triggered rollback
        }

        final testMarker = await db.query(
          'app_settings',
          where: 'key = ?',
          whereArgs: ['test_marker'],
        );
        expect(testMarker, isEmpty);
      },
    );
  });
}
