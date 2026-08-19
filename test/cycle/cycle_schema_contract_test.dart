import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/cycle_tables.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_contract.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Cycle Schema Contract Tests (Phase 11)', () {
    late Database db;

    setUp(() async {
      db = await openCycleTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('1. cycle_periods PRAGMA columns strictly match canonical contract', () async {
      final info = await db.rawQuery('PRAGMA table_info(cycle_periods);');
      final actualColumns = info.map((row) => row['name'] as String).toSet();

      final expectedColumns = CyclePeriodContract.allColumns.toSet();

      expect(
        actualColumns,
        equals(expectedColumns),
        reason: 'Columns in cycle_periods table must exactly match CyclePeriodContract.allColumns',
      );

      // Verify no phantom columns exist
      final phantomColumns = {
        'periodDuration',
        'notes',
        'suppressedPrayer',
        'fastDebtCreated',
      };

      for (final phantom in phantomColumns) {
        expect(
          actualColumns.contains(phantom),
          isFalse,
          reason: 'Phantom column $phantom must NOT exist in cycle_periods table',
        );
      }
    });

    test('2. cycle_day_logs PRAGMA columns match contract', () async {
      final info = await db.rawQuery('PRAGMA table_info(cycle_day_logs);');
      final actualColumns = info.map((row) => row['name'] as String).toSet();

      final expectedColumns = {
        'id',
        'logDate',
        'flowLevel',
        'symptomsJson',
        'mood',
        'energyTag',
        'note',
        'createdAt',
        'updatedAt',
      };

      expect(
        actualColumns,
        equals(expectedColumns),
        reason: 'Columns in cycle_day_logs table must match expected schema',
      );
    });
  });
}
