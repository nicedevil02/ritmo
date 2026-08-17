import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/catalog/wellbeing_agent_tools.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE bedtime_diagnostics (
            id TEXT PRIMARY KEY,
            date TEXT,
            durationMinutes INTEGER,
            quality INTEGER,
            awakenings INTEGER,
            bedtimeAt INTEGER,
            wakeAt INTEGER,
            note TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          );
        ''');
        await d.execute('''
          CREATE TABLE energy_logs (
            id TEXT PRIMARY KEY,
            energyLevel TEXT,
            source TEXT,
            note TEXT,
            loggedAt INTEGER,
            createdAt INTEGER
          );
        ''');
        await d.execute('''
          CREATE TABLE mood_logs (
            id TEXT PRIMARY KEY,
            mood TEXT,
            valence INTEGER,
            note TEXT,
            source TEXT,
            loggedAt INTEGER
          );
        ''');
      },
    );
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 8 Tests — AI Assistant & Wellbeing Tools (B27..B28)', () {
    test('Criterion 1: GetSleepDiagnosticsTool returns correct structured metrics and average', () async {
      await db.insert('bedtime_diagnostics', {
        'id': 's1',
        'date': '2026-08-16',
        'durationMinutes': 480,
        'quality': 4,
        'createdAt': 1723800000000,
      });
      await db.insert('bedtime_diagnostics', {
        'id': 's2',
        'date': '2026-08-17',
        'durationMinutes': 420,
        'quality': 3,
        'createdAt': 1723886400000,
      });

      const tool = GetSleepDiagnosticsTool();
      final result = await tool.execute({'days': 7});

      expect(result.isSuccess, isTrue);
      expect(result.data['count'], 2);
      expect(result.data['averageDurationMinutes'], 450); // (480 + 420) / 2 = 450
      expect(result.summaryFa, contains('2 شب ثبت‌شده'));
    });

    test('Criterion 2: GetEnergyTrendsTool counts energy distributions accurately', () async {
      await db.insert('energy_logs', {
        'id': 'e1',
        'energyLevel': 'HIGH',
        'source': 'app',
        'loggedAt': 1723800000000,
      });
      await db.insert('energy_logs', {
        'id': 'e2',
        'energyLevel': 'LOW',
        'source': 'app',
        'loggedAt': 1723886400000,
      });

      const tool = GetEnergyTrendsTool();
      final result = await tool.execute({'days': 7});

      expect(result.isSuccess, isTrue);
      expect(result.data['energyCount'], 2);
      expect(result.data['highCount'], 1);
      expect(result.data['lowCount'], 1);
      expect(result.data['mediumCount'], 0);
    });
  });
}
