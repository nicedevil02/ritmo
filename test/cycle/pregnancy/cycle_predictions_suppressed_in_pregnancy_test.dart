import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Cycle Engine Predictions Pregnancy Suppression Tests (PRG-28)', () {
    late Database db;
    late CycleEngine engine;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      engine = CycleEngine();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'CycleEngine.calculate suppresses predictions and returns pregnancy output when pregnancy mode is true',
      () async {
        final now = CycleClock.now;

        // Insert some period history
        final p1Start = CycleDateContract.cleanDate(
          now.subtract(const Duration(days: 60)),
        );
        final p1End = CycleDateContract.cleanDate(
          now.subtract(const Duration(days: 55)),
        );
        await db.insert(CyclePeriodContract.table, {
          CyclePeriodContract.colId: 'p1',
          CyclePeriodContract.colStartDate: CycleDateContract.toDayKey(p1Start),
          CyclePeriodContract.colEndDate: CycleDateContract.toDayKey(p1End),
          CyclePeriodContract.colFlowIntensity: 'MEDIUM',
          CyclePeriodContract.colIsPredicted: 0,
          CyclePeriodContract.colCreatedAt:
              CycleClock.nowMillisecondsSinceEpoch,
          CyclePeriodContract.colUpdatedAt:
              CycleClock.nowMillisecondsSinceEpoch,
        });

        final appSettings = <String, String>{
          'user_gender': 'female',
          'module_cycle_enabled': 'true',
          'cycle_setup_done': 'true',
          CycleSettings.keyPregnancyMode: 'true',
        };

        final input = CycleEngineInput(
          db: db,
          appSettings: appSettings,
          now: now,
        );

        final output = await engine.calculate(input);

        expect(output.currentPhase, CyclePhase.pregnancy);
        expect(output.nextPeriodPrediction, isNull);
        expect(output.fertileWindowStart, isNull);
        expect(output.fertileWindowEnd, isNull);
        expect(output.ovulationDay, isNull);
        expect(output.nextPeriodWindowStart, isNull);
        expect(output.nextPeriodWindowEnd, isNull);
        expect(output.pmsWindowStart, isNull);
        expect(output.pmsWindowEnd, isNull);
        expect(output.forecast, isEmpty);
        expect(output.regularityLevel, RegularityLevel.pregnancy);
        expect(output.disclaimerCode, CycleDisclaimerCode.pregnancyModeActive);
      },
    );
  });
}
