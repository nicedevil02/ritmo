import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('PregnancyOnboardingController Tests (PRG-12)', () {
    late Database db;

    setUp(() async {
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('setLmpDate automatically calculates dueDate', () {
      final controller = PregnancyOnboardingController();
      controller.setLmpDate(DateTime(2026, 1, 1));

      expect(controller.lmpDate, equals(DateTime(2026, 1, 1)));
      expect(controller.dueDate, equals(DateTime(2026, 10, 8)));
    });

    test('setDueDate automatically calculates lmpDate', () {
      final controller = PregnancyOnboardingController();
      controller.setDueDate(DateTime(2026, 10, 8));

      expect(controller.dueDate, equals(DateTime(2026, 10, 8)));
      expect(controller.lmpDate, equals(DateTime(2026, 1, 1)));
    });

    test(
      'setConceptionDate automatically synchronizes both dueDate and lmpDate',
      () {
        final controller = PregnancyOnboardingController();
        controller.setConceptionDate(DateTime(2026, 1, 15));

        expect(controller.dueDate, equals(DateTime(2026, 10, 8)));
        expect(controller.lmpDate, equals(DateTime(2026, 1, 1)));
      },
    );

    test(
      'setUltrasound automatically synchronizes both dueDate and lmpDate',
      () {
        final controller = PregnancyOnboardingController();
        controller.setUltrasound(date: DateTime(2026, 3, 1), crlMm: 45);

        expect(controller.dueDate, isNotNull);
        expect(controller.lmpDate, isNotNull);
        final span = CycleDateContract.daysBetween(
          controller.lmpDate!,
          controller.dueDate!,
        );
        expect(span, equals(280));
      },
    );

    test(
      'save writes complete profile, enables pregnancy mode flags, and sets preg_setup_done to true',
      () async {
        final controller = PregnancyOnboardingController();
        controller.setLmpDate(DateTime(2026, 1, 1));
        controller.setTone(PregnancyTone.neutral);
        controller.setAgeUnit(PregnancyAgeUnit.months);
        controller.setMultiple(true);
        controller.setHighRisk(true);
        controller.setReminderHour(8);
        controller.setVisitLeadDays(3);

        await controller.save(db: db);

        final rows = await db.query('app_settings');
        final settings = {for (final r in rows) r['key'] as String: r['value']};

        expect(settings['cycle_pregnancy_mode'], equals('true'));
        expect(settings['pregnancy_mode'], equals('true'));
        expect(settings['cycle_is_pregnant'], equals('true'));
        expect(settings['preg_setup_done'], equals('true'));
        expect(settings['preg_start_date'], equals('2026-01-01'));
        expect(settings['preg_due_date'], equals('2026-10-08'));
        expect(settings['preg_tone'], equals('neutral'));
        expect(settings['preg_age_unit'], equals('months'));
        expect(settings['preg_is_multiple'], equals('true'));
        expect(settings['preg_is_high_risk'], equals('true'));
        expect(settings['preg_reminder_hour'], equals('8'));
        expect(settings['preg_visit_reminder_lead_days'], equals('3'));

        expect(PregnancySettings.isSetupDone(settings), isTrue);
        expect(PregnancySettings.isPregnancyUsable(settings), isTrue);
      },
    );
  });
}
