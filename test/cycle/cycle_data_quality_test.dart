import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_data_quality_engine.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleDataQualityEngine Tests (C-33)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE cycle_day_logs (
                id TEXT PRIMARY KEY,
                logDate TEXT NOT NULL,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL
              )
            ''');
          },
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('C-33: evaluateDataQuality with injected now is completely deterministic', () async {
      final mockedNow = DateTime(2026, 8, 17);

      // Period started 15 days ago with no endDate (exceeds threshold 12 days)
      final periodRows = [
        {'id': 'p1', 'startDate': '2026-06-01', 'endDate': '2026-06-06'},
        {'id': 'p2', 'startDate': '2026-07-01', 'endDate': '2026-07-06'},
        {'id': 'p3', 'startDate': '2026-08-02', 'endDate': null}, // 15 days open relative to mockedNow
      ];

      final report = await CycleDataQualityEngine.evaluateDataQuality(
        db: db,
        periodRows: periodRows,
        now: mockedNow,
      );

      expect(report.hasEnoughCycles, isTrue);
      expect(report.hasForgottenOpenPeriod, isTrue);
      expect(report.hasPredictionConfidence, isFalse); // Suppressed by forgotten open period
      expect(report.warningsFa.any((w) => w.contains('دوره باز قدیمی')), isTrue);
    });
  });
}
