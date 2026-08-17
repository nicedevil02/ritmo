// C-12, C-13, C-14: Database & settings migration tests
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Cycle Data & Schema Migration Tests (C-12, C-13, C-14)', () {
    late Database db;

    setUp(() async {
      db = await CycleTestDb.createInMemoryDb();
      FlutterSecureStorage.setMockInitialValues({});
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Migrates legacy setting keys to canonical contracts (C-13)',
      () async {
        final legacySettings = {
          'cycle_avg_length': '30',
          'cycle_avg_period': '6',
          'pregnancy_mode': 'true',
          'cycle_pin_enabled': 'true',
        };

        await CycleTestDb.seedSettings(db, legacySettings);

        final rows = await db.query('app_settings');
        final settingsMap = {
          for (final r in rows)
            r['key'].toString(): r['value']?.toString() ?? '',
        };

        expect(CycleSettings.getCycleLength(settingsMap), equals(30));
        expect(CycleSettings.getPeriodDuration(settingsMap), equals(6));
        expect(CycleSettings.isPregnancyMode(settingsMap), isTrue);
        expect(CycleSettings.isLockEnabled(settingsMap), isTrue);
      },
    );

    test(
      'Parses ISO standard date strings and invalid strings gracefully (C-12)',
      () {
        const standardIsoStr = '2026-06-15';
        final parsedFromIso = CycleDateContract.parseDayKey(standardIsoStr);
        expect(parsedFromIso, isNotNull);
        expect(
          CycleDateContract.toDayKey(parsedFromIso!),
          equals('2026-06-15'),
        );

        const invalidStr = 'invalid-not-a-date';
        final parsedInvalid = CycleDateContract.parseDayKey(invalidStr);
        expect(parsedInvalid, isNull);
      },
    );

    test(
      'Handles legacy period records with null or legacy column aliases (C-14)',
      () async {
        await db.insert('cycle_periods', {
          'id': '1',
          'startDate': '2026-01-01',
          'endDate': '2026-01-06',
          'flowIntensity': 'HEAVY',
          'isPredicted': 0,
          'createdAt': 1700000000000,
          'updatedAt': 1700000000000,
        });

        final periods = await CyclePeriodRepository.instance.getAllPeriods(db);
        expect(periods.length, equals(1));
        expect(
          CycleDateContract.toDayKey(periods.first.startDate),
          equals('2026-01-01'),
        );
        expect(periods.first.endDate != null, isTrue);
        expect(
          CycleDateContract.toDayKey(periods.first.endDate!),
          equals('2026-01-06'),
        );
        expect(periods.first.isOpen, isFalse);
      },
    );
  });
}
