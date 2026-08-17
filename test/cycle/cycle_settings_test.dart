// Tests for CycleSettings (C-13) and CyclePeriodRepository (C-12, C-14)
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';

void main() {
  group('CycleSettings (C-13)', () {
    test('getCycleLength returns default when key absent', () {
      expect(CycleSettings.getCycleLength({}), CycleSettings.defaultCycleLength);
    });

    test('getCycleLength reads canonical key', () {
      expect(CycleSettings.getCycleLength({'cycle_length_days': '30'}), 30);
    });

    test('getCycleLength falls back to legacy alias cycle_avg_length', () {
      expect(CycleSettings.getCycleLength({'cycle_avg_length': '32'}), 32);
    });

    test('getCycleLength ignores out-of-range canonical value and falls back', () {
      expect(CycleSettings.getCycleLength({'cycle_length_days': '60'}), CycleSettings.defaultCycleLength);
    });

    test('getCycleLength clamps alias value if in-range', () {
      expect(CycleSettings.getCycleLength({'cycle_avg_length': '21'}), 21);
    });

    test('getPeriodDuration returns default when absent', () {
      expect(CycleSettings.getPeriodDuration({}), CycleSettings.defaultPeriodDuration);
    });

    test('getPeriodDuration reads canonical key', () {
      expect(CycleSettings.getPeriodDuration({'period_duration_days': '7'}), 7);
    });

    test('getPeriodDuration falls back to cycle_avg_period alias', () {
      expect(CycleSettings.getPeriodDuration({'cycle_avg_period': '5'}), 5);
    });

    test('getLutealPhase returns default when absent', () {
      expect(CycleSettings.getLutealPhase({}), CycleSettings.defaultLutealPhase);
    });

    test('getLutealPhase reads canonical key', () {
      expect(CycleSettings.getLutealPhase({'luteal_phase_days': '12'}), 12);
    });

    test('getLutealPhase ignores out-of-range value', () {
      expect(CycleSettings.getLutealPhase({'luteal_phase_days': '5'}), CycleSettings.defaultLutealPhase);
    });

    test('isPregnancyMode returns false when absent', () {
      expect(CycleSettings.isPregnancyMode({}), false);
    });

    test('isPregnancyMode returns true for canonical key', () {
      expect(CycleSettings.isPregnancyMode({'cycle_pregnancy_mode': 'true'}), true);
    });

    test('isPregnancyMode returns true for legacy alias pregnancy_mode', () {
      expect(CycleSettings.isPregnancyMode({'pregnancy_mode': 'true'}), true);
    });

    test('isLockEnabled defaults to true (fail-secure)', () {
      expect(CycleSettings.isLockEnabled({}), true);
    });

    test('isLockEnabled returns false when explicitly set false', () {
      expect(CycleSettings.isLockEnabled({'cycle_lock_enabled': 'false'}), false);
    });

    test('isLockEnabled returns true when explicitly set true', () {
      expect(CycleSettings.isLockEnabled({'cycle_lock_enabled': 'true'}), true);
    });
  });
}
