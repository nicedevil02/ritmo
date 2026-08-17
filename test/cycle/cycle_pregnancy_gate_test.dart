// C-40: Tests for Pregnancy Mode gating & engine calculations
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Cycle Pregnancy Mode Gate Tests (C-40)', () {
    late Database db;

    setUp(() async {
      db = await CycleTestDb.createInMemoryDb();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Engine produces pregnancy phase and regularity level when pregnancy mode enabled',
      () async {
        final now = DateTime(2026, 5, 20);

        await CycleTestDb.seedSettings(db, {
          'cycle_pregnancy_mode': 'true',
          'cycle_pregnancy_due_date': '2026-12-06',
          'user_gender': 'female',
          'module_cycle_enabled': 'true',
        });

        await CycleTestDb.seedPeriods(db, [
          {
            'id': 'period_lmp',
            'startDate': '2026-03-01',
            'endDate': '2026-03-06',
            'flowIntensity': 'MEDIUM',
            'isPredicted': 0,
            'createdAt': 1700000000000,
            'updatedAt': 1700000000000,
          },
        ]);

        final engine = CycleEngine();
        final output = await engine.calculate(
          CycleEngineInput(
            db: db,
            appSettings: {
              'cycle_pregnancy_mode': 'true',
              'cycle_pregnancy_due_date': '2026-12-06',
              'user_gender': 'female',
              'module_cycle_enabled': 'true',
            },
            now: now,
          ),
        );

        expect(output.currentPhase, equals(CyclePhase.pregnancy));
        expect(output.regularityLevel, equals(RegularityLevel.pregnancy));
        expect(output.hasData, isTrue);
      },
    );

    test('CycleSettings correctly reflects pregnancy mode toggle', () {
      expect(CycleSettings.isPregnancyMode({}), isFalse);
      expect(
        CycleSettings.isPregnancyMode({'cycle_pregnancy_mode': 'false'}),
        isFalse,
      );
      expect(
        CycleSettings.isPregnancyMode({'cycle_pregnancy_mode': 'true'}),
        isTrue,
      );
      expect(CycleSettings.isPregnancyMode({'pregnancy_mode': 'true'}), isTrue);
    });
  });
}
