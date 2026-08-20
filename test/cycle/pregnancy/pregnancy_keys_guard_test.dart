import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';

void main() {
  group('Pregnancy Keys Guard Test (PRG-42)', () {
    test('all dedicated keys have preg_prefix and no collision', () {
      const keys = PregnancySettings.allKeys;
      expect(keys.length, greaterThanOrEqualTo(22));

      for (final key in keys) {
        expect(key.startsWith('preg_'), isTrue, reason: 'Key $key must start with preg_');
        expect(key, isNot(startsWith('cycle_')), reason: 'Key $key must not collide with cycle_ prefix');
      }

      // Check uniqueness
      final uniqueKeys = keys.toSet();
      expect(uniqueKeys.length, keys.length, reason: 'Keys in allKeys must be unique');
    });

    test('pregnancyFlagKeys contains exactly the 3 sync flags', () {
      const flags = PregnancySettings.pregnancyFlagKeys;
      expect(flags, containsAll([
        'cycle_pregnancy_mode',
        'pregnancy_mode',
        'cycle_is_pregnant',
      ]));
      expect(flags.length, 3);
    });

    test('default PregnancyProfile values are sound and consistent', () {
      final defaultProfile = PregnancyProfile.fromMap(const {});

      expect(defaultProfile.eddSource, PregnancyEddSource.lmp);
      expect(defaultProfile.tone, PregnancyTone.warm);
      expect(defaultProfile.ageUnit, PregnancyAgeUnit.weeks);
      expect(defaultProfile.isMultiple, isFalse);
      expect(defaultProfile.isHighRisk, isFalse);
      expect(defaultProfile.sectionHidden, isFalse);
      expect(defaultProfile.maskNotifications, isFalse);
      expect(defaultProfile.lockEnabled, isFalse);
      expect(defaultProfile.kickTargetCount, 10);
      expect(defaultProfile.kickWindowMinutes, 120);
      expect(defaultProfile.kickBaselineComparison, isFalse);
      expect(defaultProfile.showCountdown, isTrue);
      expect(defaultProfile.supplementReminder, isFalse);
      expect(defaultProfile.kickReminder, isFalse);

      final diff = CycleDateContract.daysBetween(defaultProfile.lmpDate, defaultProfile.dueDate);
      expect(diff, 280);
    });

    test('round-trip profile serialization preserves all properties', () {
      final now = CycleClock.now;
      final lmp = CycleDateContract.cleanDate(now.subtract(const Duration(days: 40)));
      final due = CycleDateContract.cleanDate(now.add(const Duration(days: 240)));

      final original = PregnancyProfile(
        lmpDate: lmp,
        dueDate: due,
        eddSource: PregnancyEddSource.ultrasound,
        tone: PregnancyTone.neutral,
        ageUnit: PregnancyAgeUnit.months,
        isMultiple: true,
        isHighRisk: true,
        sectionHidden: true,
        maskNotifications: true,
        lockEnabled: true,
        cycleResumeReminder: true,
        kickTargetCount: 15,
        kickWindowMinutes: 90,
        kickBaselineComparison: false,
        visitReminderLeadDays: 5,
        reminderHour: 8,
        showCountdown: false,
        supplementReminder: false,
        kickReminder: false,
      );

      final map = PregnancySettings.toMap(original);
      final restored = PregnancySettings.loadProfile(map);

      expect(CycleDateContract.cleanDate(restored.lmpDate), lmp);
      expect(CycleDateContract.cleanDate(restored.dueDate), due);
      expect(restored.eddSource, PregnancyEddSource.ultrasound);
      expect(restored.tone, PregnancyTone.neutral);
      expect(restored.ageUnit, PregnancyAgeUnit.months);
      expect(restored.isMultiple, isTrue);
      expect(restored.isHighRisk, isTrue);
      expect(restored.sectionHidden, isTrue);
      expect(restored.maskNotifications, isTrue);
      expect(restored.lockEnabled, isTrue);
      expect(restored.cycleResumeReminder, isTrue);
      expect(restored.kickTargetCount, 15);
      expect(restored.kickWindowMinutes, 90);
      expect(restored.kickBaselineComparison, isFalse);
      expect(restored.visitReminderLeadDays, 5);
      expect(restored.reminderHour, 8);
      expect(restored.showCountdown, isFalse);
      expect(restored.supplementReminder, isFalse);
      expect(restored.kickReminder, isFalse);
    });
  });
}
