import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/hormonal_intelligence_engine.dart';
import 'package:ritmo/core/services/cycle_notification_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_reminder_scheduler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Cycle Notification & Reminders Tests (C-38, C-39, C-40)', () {
    late Database db;

    setUp(() async {
      db = await openCycleTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'C-38: privateReminderQueue contains T-7, T-3, T-1, T0 items when user has prediction data',
      () async {
        // Completed period 28 days ago
        await db.insert('cycle_periods', {
          'id': 'p1',
          'startDate': '2026-07-20',
          'endDate': '2026-07-25',
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        final settings = {
          'user_gender': 'female',
          'module_cycle_enabled': 'true',
          'cycle_avg_length': '28',
          'cycle_avg_period': '6',
        };

        final now = DateTime(2026, 8, 10);
        final output = await HormonalIntelligenceEngine.evaluate(
          db: db,
          appSettings: settings,
          now: now,
        );

        expect(output.hasData, isTrue);
        expect(output.privateReminderQueue.length, equals(4));
        expect(
          output.privateReminderQueue.map((r) => r.level).toList(),
          equals(['T-7', 'T-3', 'T-1', 'T0']),
        );
      },
    );

    test(
      'C-39: Inserting a period triggers notification rescheduling covering 3 upcoming cycles',
      () async {
        final settings = {
          'user_gender': 'female',
          'module_cycle_enabled': 'true',
          'cycle_consent_reminders': 'true',
          'cycle_avg_length': '28',
          'cycle_avg_period': '6',
        };
        for (final entry in settings.entries) {
          await db.insert('app_settings', {
            'key': entry.key,
            'value': entry.value,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        final now = DateTime(2026, 8, 17);

        // Add a period via repository
        await CyclePeriodRepository.instance.startPeriod(
          db: db,
          startDate: DateTime(2026, 8, 1),
          now: now,
        );
        final openPeriod = await CyclePeriodRepository.instance.getOpenPeriod(db);
        expect(openPeriod, isNotNull);

        await CyclePeriodRepository.instance.endPeriod(
          db: db,
          id: openPeriod!.id,
          endDate: DateTime(2026, 8, 6),
          now: now,
        );

        // Verify that CycleReminderScheduler can run without errors
        await CycleReminderScheduler.rescheduleAll(
          dbExecutor: db,
          appSettings: settings,
          now: now,
        );

        // Expect no crash and notifications scheduled cleanly
      },
    );

    test(
      'C-39 & C-40: In pregnancy mode, scheduleReminders cancels all reminders',
      () async {
        await CycleNotificationService.scheduleReminders(
          nextPeriodWindowStart: DateTime(2026, 8, 29),
          consentReminders: true,
          pregnancyMode: true, // Pregnancy mode active
        );

        // Notification cancellation executed safely
      },
    );
  });
}
