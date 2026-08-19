// C-20, C-21: CycleEngine Regularity & Completed Cycles Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleEngine Regularity and Statistics Tests', () {
    late Database db;
    late CycleEngine engine;

    setUp(() async {
      db = await openCycleTestDb();
      engine = CycleEngine();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'C-21: Single recorded period has completedCycles == 0, regularityScore == null, and dataMaturity == LOW',
      () async {
        await db.insert('cycle_periods', {
          'id': '1',
          'startDate': '2026-08-01',
          'endDate': '2026-08-06',
        });

        final settings = {
          'user_gender': 'FEMALE',
          'module_cycle_enabled': 'true',
        };

        final now = DateTime(2026, 8, 10);
        final output = await engine.calculate(
          CycleEngineInput(db: db, appSettings: settings, now: now),
        );

        expect(output.stats.recordedPeriods, equals(1));
        expect(output.stats.completedCycles, equals(0));
        expect(output.regularityScore, isNull);
        expect(output.dataMaturity, equals('LOW'));
        expect(
          output.regularityLevel,
          equals(RegularityLevel.insufficientData),
        );
      },
    );

    test(
      'C-20: Regularity is consistent between isIrregular and regularityLevel/regularityLabel',
      () async {
        // 4 periods -> 3 completed cycles: 28, 29, 28 (very regular)
        await db.insert('cycle_periods', {
          'id': '1',
          'startDate': '2026-01-01',
          'endDate': '2026-01-06',
        });
        await db.insert('cycle_periods', {
          'id': '2',
          'startDate': '2026-01-29',
          'endDate': '2026-02-03',
        }); // 28 days
        await db.insert('cycle_periods', {
          'id': '3',
          'startDate': '2026-02-27',
          'endDate': '2026-03-04',
        }); // 29 days
        await db.insert('cycle_periods', {
          'id': '4',
          'startDate': '2026-03-27',
          'endDate': '2026-04-01',
        }); // 28 days

        final settings = {
          'user_gender': 'FEMALE',
          'module_cycle_enabled': 'true',
        };

        final now = DateTime(2026, 4, 10);
        final output = await engine.calculate(
          CycleEngineInput(db: db, appSettings: settings, now: now),
        );

        expect(output.stats.completedCycles, equals(3));
        expect(output.isIrregular, isFalse);
        expect(output.regularityLevel, equals(RegularityLevel.regular));
        expect(output.regularityScore, isNotNull);
        expect(output.regularityScore, greaterThanOrEqualTo(90));
        expect(output.dataMaturity, equals('MEDIUM'));
      },
    );
  });
}
