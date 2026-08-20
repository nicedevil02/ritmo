import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/services/cycle_notification_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Cycle Notification Service Pregnancy Suppression Tests (PRG-27)', () {
    late Database db;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      await db.execute('''
        CREATE TABLE IF NOT EXISTS alarm_delivery_log (
          id TEXT PRIMARY KEY,
          channel TEXT,
          scheduledAt INTEGER,
          title TEXT,
          body TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_reminders (
          id TEXT PRIMARY KEY,
          routineId TEXT,
          scheduledTime INTEGER
        );
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('scheduleForecastReminders with pregnancyMode=true does not schedule reminders', () async {
      final now = CycleClock.now;
      final forecastCycles = [
        PredictedCycle(
          index: 1,
          predictedStart: now.add(const Duration(days: 10)),
          predictedEnd: now.add(const Duration(days: 15)),
          windowStart: now.add(const Duration(days: 8)),
          windowEnd: now.add(const Duration(days: 12)),
          sigmaDays: 2.0,
          periodDays: 5,
          confidence: 0.9,
          confidenceLevel: PredictionConfidenceLevel.high,
          basis: ForecastBasis.measured,
        ),
      ];

      await CycleNotificationService.scheduleForecastReminders(
        forecastCycles: forecastCycles,
        consentReminders: true,
        pregnancyMode: true,
        now: now,
      );

      final logRows = await db.query('alarm_delivery_log');
      expect(logRows, isEmpty);
    });

    test('scheduleReminders with pregnancyMode=true does not schedule reminders', () async {
      final now = CycleClock.now;
      final nextPeriod = now.add(const Duration(days: 10));

      await CycleNotificationService.scheduleReminders(
        nextPeriodWindowStart: nextPeriod,
        consentReminders: true,
        pregnancyMode: true,
        now: now,
      );

      final logRows = await db.query('alarm_delivery_log');
      expect(logRows, isEmpty);
    });
  });
}
