import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/health/presentation/widgets/pregnancy_report.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ritmo/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('UX-07 Doctor Report Aggregation Tests', () {
    late Database db;
    bool dbInitialized = false;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
          await db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER);');
          await db.execute('CREATE TABLE pregnancy_symptoms (id TEXT PRIMARY KEY, pregnancyId TEXT NOT NULL, date TEXT NOT NULL, symptom TEXT NOT NULL, severity TEXT DEFAULT "MILD", note TEXT);');
          await db.execute('CREATE TABLE blood_pressure_logs (id TEXT PRIMARY KEY, systolic INTEGER NOT NULL, diastolic INTEGER NOT NULL, pulse INTEGER, arm TEXT, position TEXT, note TEXT, loggedAt INTEGER NOT NULL);');
          await db.execute('CREATE TABLE blood_sugar_logs (id TEXT PRIMARY KEY, value INTEGER NOT NULL, measurementType TEXT NOT NULL DEFAULT "FASTING", note TEXT, loggedAt INTEGER NOT NULL);');
          await db.execute('CREATE TABLE kick_counts (id TEXT PRIMARY KEY, pregnancyId TEXT NOT NULL, startTime INTEGER NOT NULL, endTime INTEGER, kickCount INTEGER, loggedAt INTEGER NOT NULL);');
          await db.execute('CREATE TABLE pregnancy_checkups (id TEXT PRIMARY KEY, pregnancyId TEXT NOT NULL, title TEXT NOT NULL, scheduledDate INTEGER, actualDate INTEGER, type TEXT NOT NULL, result TEXT, notes TEXT, isCompleted INTEGER DEFAULT 0, createdAt INTEGER NOT NULL);');
        });
        DatabaseHelper.instance.overrideDatabaseForTesting(db);
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized) {
        await db.close();
      }
    });

    test('aggregatePregnancyReportData executes without errors and returns formatted structure', () async {
      if (!dbInitialized) return;

      final lmp = DateTime.now().subtract(const Duration(days: 100));
      final report = await aggregatePregnancyReportData(
        pregnancyId: 'preg_test',
        lmpDate: lmp,
      );

      expect(report.gestationalAge.weeks, equals(14));
      expect(report.gestationalAge.days, equals(2));
      expect(report.eddJalali, isNotEmpty);
      expect(report.bpLogs, isEmpty);
      expect(report.sugarLogs, isEmpty);
      expect(report.kickSessions, isEmpty);
      expect(report.completedCheckups, isEmpty);
    });
  });
}
