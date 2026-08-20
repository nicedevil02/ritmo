import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('PregnancySettings Persistence Tests (PRG-03)', () {
    late Database db;

    setUp(() async {
      CycleClock.nowProvider = () => DateTime(2026, 6, 1);
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
      CycleClock.reset();
    });

    test('saveProfile and loadProfile roundtrip through database', () async {
      final profile = PregnancyProfile(
        lmpDate: DateTime(2026, 2, 1),
        dueDate: DateTime(2026, 11, 8),
        eddSource: PregnancyEddSource.ultrasound,
        tone: PregnancyTone.neutral,
        ageUnit: PregnancyAgeUnit.months,
        isMultiple: true,
        isHighRisk: true,
        sectionHidden: true,
        maskNotifications: true,
        lockEnabled: true,
        cycleResumeReminder: true,
        kickTargetCount: 12,
        kickWindowMinutes: 90,
        kickBaselineComparison: true,
        visitReminderLeadDays: 4,
        reminderHour: 9,
      );

      await PregnancySettings.saveProfile(profile, db);

      final rows = await db.query('app_settings');
      final settings = {for (final r in rows) r['key'] as String: r['value']};

      final loaded = PregnancySettings.loadProfile(settings);
      expect(loaded, equals(profile));
      expect(CycleDateContract.toDayKey(loaded.lmpDate), equals('2026-02-01'));
      expect(CycleDateContract.toDayKey(loaded.dueDate), equals('2026-11-08'));
      expect(loaded.eddSource, equals(PregnancyEddSource.ultrasound));
      expect(loaded.tone, equals(PregnancyTone.neutral));
      expect(loaded.ageUnit, equals(PregnancyAgeUnit.months));
      expect(loaded.isMultiple, isTrue);
      expect(loaded.isHighRisk, isTrue);
      expect(loaded.sectionHidden, isTrue);
      expect(loaded.maskNotifications, isTrue);
      expect(loaded.lockEnabled, isTrue);
      expect(loaded.cycleResumeReminder, isTrue);
      expect(loaded.kickTargetCount, equals(12));
      expect(loaded.kickWindowMinutes, equals(90));
      expect(loaded.kickBaselineComparison, isTrue);
      expect(loaded.visitReminderLeadDays, equals(4));
      expect(loaded.reminderHour, equals(9));
    });

    test('isSetupDone returns true only when preg_setup_done is true', () {
      expect(PregnancySettings.isSetupDone(const {}), isFalse);
      expect(
        PregnancySettings.isSetupDone(const {'preg_setup_done': 'false'}),
        isFalse,
      );
      expect(
        PregnancySettings.isSetupDone(const {'preg_setup_done': 'true'}),
        isTrue,
      );
    });

    test('clearAll removes all preg_* keys from app_settings', () async {
      final profile = PregnancyProfile(
        lmpDate: DateTime(2026, 2, 1),
        dueDate: DateTime(2026, 11, 8),
      );
      await PregnancySettings.saveProfile(profile, db);

      // Verify keys exist
      var rows = await db.query('app_settings', where: "key GLOB 'preg_*'");
      expect(rows, isNotEmpty);

      // Clear all
      await PregnancySettings.clearAll(db);

      // Verify no preg_* keys remain
      rows = await db.query('app_settings', where: "key GLOB 'preg_*'");
      expect(rows, isEmpty);

      // Non-preg keys must still remain intact
      final nonPregRows = await db.query(
        'app_settings',
        where: "key NOT GLOB 'preg_*'",
      );
      expect(nonPregRows, isNotEmpty);
    });
  });
}
