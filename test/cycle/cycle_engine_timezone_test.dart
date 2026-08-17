// DST and timezone stability test for CycleEngine and CycleDateContract
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleEngine Timezone and DST Tests', () {
    late Database db;
    late CycleEngine engine;

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updatedAt INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE cycle_periods (
            id TEXT PRIMARY KEY,
            startDate TEXT NOT NULL,
            endDate TEXT,
            flowIntensity TEXT,
            isPredicted INTEGER DEFAULT 0,
            note TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          )
        ''');
      });

      engine = CycleEngine();

      await db.insert('app_settings', {'key': 'user_gender', 'value': 'FEMALE'});
      await db.insert('app_settings', {'key': 'module_cycle_enabled', 'value': 'true'});
      await db.insert('app_settings', {'key': 'cycle_avg_length', 'value': '28'});
      await db.insert('app_settings', {'key': 'cycle_avg_period', 'value': '6'});
    });

    tearDown(() async {
      await db.close();
    });

    test('DST boundary transition does not shift dayOfCycle or daysBetween calculation', () async {
      // Simulating a 28-day span across a 23-hour or 25-hour day transition
      final startDate = DateTime(2026, 3, 15, 23, 30);
      final evalDate = DateTime(2026, 4, 15, 0, 30);

      final days = CycleDateContract.daysBetween(startDate, evalDate);
      expect(days, equals(31));

      await db.insert('cycle_periods', {
        'id': '1',
        'startDate': CycleDateContract.toDayKey(startDate),
        'endDate': CycleDateContract.toDayKey(startDate.add(const Duration(days: 5))),
      });

      final settings = {
        'user_gender': 'FEMALE',
        'module_cycle_enabled': 'true',
      };

      final output = await engine.calculate(CycleEngineInput(db: db, appSettings: settings, now: evalDate));
      expect(output.dayOfCycle, equals(32)); // days + 1
    });
  });
}
