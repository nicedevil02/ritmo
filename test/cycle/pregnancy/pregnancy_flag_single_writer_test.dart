import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('PregnancyFlagSingleWriter Tests (PRG-04)', () {
    late Database db;

    setUp(() async {
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('setPregnancyActive(true) writes all three flags simultaneously to true', () async {
      await PregnancySettings.setPregnancyActive(true, db: db);

      final rows = await db.query(
        'app_settings',
        where: 'key IN (?, ?, ?)',
        whereArgs: [
          PregnancySettings.keyCyclePregnancyMode,
          PregnancySettings.keyPregnancyMode,
          PregnancySettings.keyCycleIsPregnant,
        ],
      );

      expect(rows.length, equals(3));
      for (final row in rows) {
        expect(row['value'], equals('true'));
      }
    });

    test('setPregnancyActive(false) writes all three flags simultaneously to false', () async {
      // First enable
      await PregnancySettings.setPregnancyActive(true, db: db);

      // Now disable
      await PregnancySettings.setPregnancyActive(false, db: db);

      final rows = await db.query(
        'app_settings',
        where: 'key IN (?, ?, ?)',
        whereArgs: [
          PregnancySettings.keyCyclePregnancyMode,
          PregnancySettings.keyPregnancyMode,
          PregnancySettings.keyCycleIsPregnant,
        ],
      );

      expect(rows.length, equals(3));
      for (final row in rows) {
        expect(row['value'], equals('false'));
      }
    });

    test('setPregnancyActive works within a transaction', () async {
      await db.transaction((txn) async {
        await PregnancySettings.setPregnancyActive(true, db: txn);
      });

      final rows = await db.query(
        'app_settings',
        where: 'key IN (?, ?, ?)',
        whereArgs: [
          PregnancySettings.keyCyclePregnancyMode,
          PregnancySettings.keyPregnancyMode,
          PregnancySettings.keyCycleIsPregnant,
        ],
      );

      expect(rows.length, equals(3));
      for (final row in rows) {
        expect(row['value'], equals('true'));
      }
    });
  });
}
