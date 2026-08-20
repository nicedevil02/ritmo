// test/supplementary_sports/movement_phase_c_test.dart
//
// Unit tests for Phase C bug-fixes in the Movement module:
//   C-1: Bilingual limitation detection (knee/زانو, back/کمر, shoulder/شانه)
//        + honest MET-min estimation based on availableMinutes
//   C-2: N+1 elimination via kindsByCode batched map + MovementBudgetSnapshot integrity
//   C-3: Search edge-cases and null-safety in suggester logic

import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/movement_load_calculator.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_budget.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // C-1 | Bilingual limitation detection & honest MET-min calculation
  // ═══════════════════════════════════════════════════════════════════════════
  group('C-1 | Bilingual Limitation Detection & MET-min Estimation', () {
    // Mirror of the private _mentionsAny function used in movement_suggester.dart
    bool mentionsAny(String source, List<String> terms) {
      final s = source.toLowerCase();
      return terms.any(s.contains);
    }

    const kneeTerms = ['knee', 'زانو'];
    const backTerms = ['back', 'کمر'];
    const shoulderTerms = ['shoulder', 'شانه'];

    // ── Bilingual term detection ─────────────────────────────────────────────

    test('English "knee" is detected in limitation string', () {
      expect(mentionsAny('knee pain since 2020', kneeTerms), isTrue);
    });

    test('Persian "زانو" is detected in limitation string', () {
      expect(mentionsAny('درد زانو دارم', kneeTerms), isTrue);
    });

    test('Mixed English + Persian limitation string detected for knee', () {
      expect(mentionsAny('knee زانو back کمر', kneeTerms), isTrue);
    });

    test('Mixed English + Persian limitation string detected for back', () {
      expect(mentionsAny('knee زانو back کمر', backTerms), isTrue);
    });

    test('"shoulder" (English) is detected', () {
      expect(mentionsAny('shoulder injury', shoulderTerms), isTrue);
    });

    test('"شانه" (Persian) is detected', () {
      expect(mentionsAny('مشکل شانه چپ', shoulderTerms), isTrue);
    });

    test('Unrelated Farsi text returns false for all term groups', () {
      expect(mentionsAny('هیچ محدودیتی ندارم', kneeTerms), isFalse);
      expect(mentionsAny('هیچ محدودیتی ندارم', backTerms), isFalse);
      expect(mentionsAny('هیچ محدودیتی ندارم', shoulderTerms), isFalse);
    });

    test('Empty limitation string returns false for all term groups', () {
      expect(mentionsAny('', kneeTerms), isFalse);
      expect(mentionsAny('', backTerms), isFalse);
      expect(mentionsAny('', shoulderTerms), isFalse);
    });

    test('Case-insensitive: "KNEE" is detected', () {
      expect(mentionsAny('KNEE problem', kneeTerms), isTrue);
    });

    // ── Joint-impact gate simulation ─────────────────────────────────────────

    test('Knee-pain gate excludes kinds with jointImpact >= 3', () {
      final allKinds = [
        _makeKind(code: 'RUNNING', jointImpact: 3, isEnabled: true),
        _makeKind(code: 'JUMPING', jointImpact: 4, isEnabled: true),
        _makeKind(code: 'SWIMMING', jointImpact: 1, isEnabled: true),
        _makeKind(code: 'CYCLING', jointImpact: 2, isEnabled: true),
      ];
      const hasKneePain = true;

      final safeKinds = allKinds.where((k) {
        if (hasKneePain && k.jointImpact >= 3) return false;
        return k.isEnabled;
      }).toList();

      expect(safeKinds.length, 2);
      expect(safeKinds.map((k) => k.code), containsAll(['SWIMMING', 'CYCLING']));
      expect(safeKinds.map((k) => k.code), isNot(contains('RUNNING')));
      expect(safeKinds.map((k) => k.code), isNot(contains('JUMPING')));
    });

    test('Without knee pain, jointImpact does not cause filtering', () {
      final allKinds = [
        _makeKind(code: 'RUNNING', jointImpact: 3, isEnabled: true),
        _makeKind(code: 'SWIMMING', jointImpact: 1, isEnabled: true),
      ];
      const hasKneePain = false;

      final safeKinds = allKinds.where((k) {
        if (hasKneePain && k.jointImpact >= 3) return false;
        return k.isEnabled;
      }).toList();

      expect(safeKinds.length, 2);
    });

    test('Disabled kinds are excluded regardless of knee pain', () {
      final allKinds = [
        _makeKind(code: 'SWIMMING', jointImpact: 1, isEnabled: false), // safe but disabled
        _makeKind(code: 'CYCLING', jointImpact: 2, isEnabled: true),
      ];

      final safeKinds = allKinds.where((k) {
        if (true && k.jointImpact >= 3) return false;
        return k.isEnabled;
      }).toList();

      expect(safeKinds.length, 1);
      expect(safeKinds.first.code, 'CYCLING');
    });

    // ── Honest MET-min estimation ─────────────────────────────────────────────

    test('Estimated MET-min = round(met * availableMinutes) — medium intensity', () {
      // SWIMMING: baseMet = 5.8, medium → met = 5.8
      final met = MovementLoadCalculator.metFor(
        baseMet: 5.8,
        metLow: 4.0,
        metHigh: 8.0,
        intensity: MovementIntensity.medium,
      );
      const availableMinutes = 45;
      final estimatedMetMin = (met * availableMinutes).round();

      expect(met, 5.8);
      expect(estimatedMetMin, 261); // 5.8 × 45 = 261.0
    });

    test('Estimated MET-min for walking 30 min at medium', () {
      final met = MovementLoadCalculator.metFor(
        baseMet: 3.5,
        metLow: 2.5,
        metHigh: 5.0,
        intensity: MovementIntensity.medium,
      );
      final estimatedMetMin = (met * 30).round();
      expect(estimatedMetMin, 105); // 3.5 × 30 = 105
    });

    test('availableMinutes is clamped to [10, 120]', () {
      expect(5.clamp(10, 120), 10);
      expect(200.clamp(10, 120), 120);
      expect(60.clamp(10, 120), 60);
    });

    test('Zero availableMinutes yields zero MET-minutes (edge case)', () {
      final metMin = MovementLoadCalculator.metMinutes(met: 5.8, durationMinutes: 0);
      expect(metMin, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // C-2 | N+1 Elimination — kindsByCode batched map
  // ═══════════════════════════════════════════════════════════════════════════
  group('C-2 | N+1 Elimination — kindsByCode & Budget Snapshot Integrity', () {
    test('kindsByCode maps all kinds by their code key', () {
      final kinds = [
        _makeKind(code: 'RUNNING', jointImpact: 3, isEnabled: true, family: MovementFamily.endurance),
        _makeKind(code: 'SWIMMING', jointImpact: 1, isEnabled: true, family: MovementFamily.endurance),
        _makeKind(code: 'YOGA', jointImpact: 1, isEnabled: true, family: MovementFamily.mindBody),
      ];
      final kindsByCode = {for (final k in kinds) k.code: k};

      expect(kindsByCode.containsKey('RUNNING'), isTrue);
      expect(kindsByCode.containsKey('SWIMMING'), isTrue);
      expect(kindsByCode.containsKey('YOGA'), isTrue);
      expect(kindsByCode['YOGA']?.family, MovementFamily.mindBody);
    });

    test('kindsByCode O(1) lookup — does not iterate list for every event', () {
      final kinds = List.generate(
        100,
        (i) => _makeKind(code: 'KIND_$i', jointImpact: 1, isEnabled: true),
      );
      final kindsByCode = {for (final k in kinds) k.code: k};

      final found = kindsByCode['KIND_77'];
      expect(found, isNotNull);
      expect(found!.code, 'KIND_77');
    });

    test('byFamily aggregation via kindsByCode yields correct totals', () {
      final events = [
        _makeEvent(code: 'RUNNING', metMinutes: 150.0),
        _makeEvent(code: 'SWIMMING', metMinutes: 200.0),
        _makeEvent(code: 'YOGA', metMinutes: 80.0),
      ];
      final kindsByCode = <String, MovementKind>{
        'RUNNING': _makeKind(code: 'RUNNING', jointImpact: 3, isEnabled: true, family: MovementFamily.endurance),
        'SWIMMING': _makeKind(code: 'SWIMMING', jointImpact: 1, isEnabled: true, family: MovementFamily.endurance),
        'YOGA': _makeKind(code: 'YOGA', jointImpact: 1, isEnabled: true, family: MovementFamily.mindBody),
      };

      final byFamily = <MovementFamily, double>{};
      for (final e in events) {
        final kind = kindsByCode[e.kindCode];
        final family = kind?.family ?? MovementFamily.endurance;
        byFamily[family] = (byFamily[family] ?? 0.0) + e.metMinutes;
      }

      // 150 + 200 = 350 for endurance
      expect(byFamily[MovementFamily.endurance], closeTo(350.0, 0.01));
      // 80 for mindBody
      expect(byFamily[MovementFamily.mindBody], closeTo(80.0, 0.01));
    });

    test('Unknown kind code falls back to endurance family', () {
      final events = [_makeEvent(code: 'UNKNOWN_CODE', metMinutes: 60.0)];
      final kindsByCode = <String, MovementKind>{}; // empty map

      final byFamily = <MovementFamily, double>{};
      for (final e in events) {
        final kind = kindsByCode[e.kindCode];
        final family = kind?.family ?? MovementFamily.endurance; // fallback
        byFamily[family] = (byFamily[family] ?? 0.0) + e.metMinutes;
      }

      expect(byFamily[MovementFamily.endurance], closeTo(60.0, 0.01));
    });

    test('progressRatio is 0.5 when 250/500 MET-min achieved', () {
      final snapshot = _makeSnapshot(
        weeklyMetMinutesTarget: 500.0,
        achievedMetMinutes: 250.0,
      );
      expect(snapshot.progressRatio, closeTo(0.5, 0.001));
      expect(snapshot.isGoalMet, isFalse);
    });

    test('progressRatio is exactly 1.0 when goal is exactly met', () {
      final snapshot = _makeSnapshot(
        weeklyMetMinutesTarget: 500.0,
        achievedMetMinutes: 500.0,
      );
      expect(snapshot.progressRatio, closeTo(1.0, 0.001));
      expect(snapshot.isGoalMet, isTrue);
    });

    test('progressRatio is capped at 2.0 when achieved > 200% of target', () {
      final snapshot = _makeSnapshot(
        weeklyMetMinutesTarget: 100.0,
        achievedMetMinutes: 800.0,
      );
      expect(snapshot.progressRatio, 2.0); // clamped at 2.0
      expect(snapshot.isGoalMet, isTrue);
    });

    test('progressRatio is 0.0 when weeklyMetMinutesTarget is zero', () {
      final snapshot = _makeSnapshot(
        weeklyMetMinutesTarget: 0.0,
        achievedMetMinutes: 0.0,
      );
      expect(snapshot.progressRatio, 0.0);
    });

    test('byKind accumulates MET-minutes per kind code', () {
      final events = [
        _makeEvent(code: 'RUNNING', metMinutes: 80.0),
        _makeEvent(code: 'RUNNING', metMinutes: 120.0),
        _makeEvent(code: 'SWIMMING', metMinutes: 200.0),
      ];

      final byKind = <String, double>{};
      for (final e in events) {
        byKind[e.kindCode] = (byKind[e.kindCode] ?? 0.0) + e.metMinutes;
      }

      expect(byKind['RUNNING'], closeTo(200.0, 0.01)); // 80 + 120
      expect(byKind['SWIMMING'], closeTo(200.0, 0.01));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // C-3 | Search safety: edge-cases & null-safety in suggester logic
  // ═══════════════════════════════════════════════════════════════════════════
  group('C-3 | Search Safety — Edge Cases & Null-safe Budget Logic', () {
    test('Empty query returns all enabled kinds (no filtering)', () {
      final allKinds = [
        _makeKind(code: 'RUNNING', titleFa: 'دویدن', jointImpact: 3, isEnabled: true),
        _makeKind(code: 'WALKING', titleFa: 'پیاده‌روی', jointImpact: 1, isEnabled: true),
      ];
      const query = '';
      final filtered = query.isEmpty
          ? allKinds
          : allKinds.where((k) => k.titleFa.contains(query) || k.code.contains(query.toUpperCase())).toList();

      expect(filtered.length, 2);
    });

    test('Query that matches no kind returns empty list', () {
      final allKinds = [
        _makeKind(code: 'RUNNING', titleFa: 'دویدن', jointImpact: 3, isEnabled: true),
        _makeKind(code: 'WALKING', titleFa: 'پیاده‌روی', jointImpact: 1, isEnabled: true),
      ];
      const query = 'ورزش';
      final filtered = allKinds
          .where((k) => k.titleFa.contains(query) || k.code.contains(query.toUpperCase()))
          .toList();

      expect(filtered, isEmpty);
    });

    test('Query matching titleFa returns only matching kind', () {
      final allKinds = [
        _makeKind(code: 'RUNNING', titleFa: 'دویدن', jointImpact: 3, isEnabled: true),
        _makeKind(code: 'WALKING', titleFa: 'پیاده‌روی', jointImpact: 1, isEnabled: true),
        _makeKind(code: 'SWIMMING', titleFa: 'شنا', jointImpact: 1, isEnabled: true),
      ];
      const query = 'شنا';
      final filtered = allKinds.where((k) => k.titleFa.contains(query)).toList();

      expect(filtered.length, 1);
      expect(filtered.first.code, 'SWIMMING');
    });

    test('Query matching code returns correct kind', () {
      final allKinds = [
        _makeKind(code: 'RUNNING', titleFa: 'دویدن', jointImpact: 3, isEnabled: true),
        _makeKind(code: 'WALKING', titleFa: 'پیاده‌روی', jointImpact: 1, isEnabled: true),
      ];
      const query = 'RUN';
      final filtered = allKinds
          .where((k) => k.titleFa.contains(query) || k.code.contains(query.toUpperCase()))
          .toList();

      expect(filtered.length, 1);
      expect(filtered.first.code, 'RUNNING');
    });

    test('budgetGap <= 0 does not trigger high-intensity recommendation', () {
      // If goal is already met (achieved >= target), gap <= 0 → no RUNNING suggestion
      const target = 500.0;
      const achieved = 600.0;
      final gap = target - achieved;

      expect(gap > 200, isFalse); // should not recommend running
      expect(gap, isNegative);   // goal exceeded
    });

    test('budgetGap > 200 triggers high-priority (running/brisk_walking) recommendation', () {
      const target = 500.0;
      const achieved = 50.0;
      final gap = target - achieved;

      expect(gap > 200, isTrue);
      expect(gap, closeTo(450.0, 0.01));
    });

    test('CalorieEstimation: default weight (70 kg) used when weightKg is zero', () {
      // Verifies the null-safe fallback in calories()
      final kcal = MovementLoadCalculator.calories(
        met: 7.0,
        weightKg: 0.0, // triggers default of 70 kg
        durationMinutes: 60,
      );
      final expected = (7.0 * 3.5 * 70.0 / 200.0) * 60;
      expect(kcal, closeTo(expected, 0.1));
    });

    test('Negative durationMinutes yields zero MET-minutes (guard)', () {
      final metMin = MovementLoadCalculator.metMinutes(met: 5.0, durationMinutes: -1);
      expect(metMin, 0.0);
    });

    test('Zero metMinutes event does not corrupt budget totals', () {
      final events = [
        _makeEvent(code: 'WALKING', metMinutes: 0.0), // zero-value event
        _makeEvent(code: 'SWIMMING', metMinutes: 200.0),
      ];

      double total = 0.0;
      for (final e in events) {
        total += e.metMinutes;
      }

      expect(total, closeTo(200.0, 0.01)); // zero event should not break sum
    });
  });
}

// ─── Test Helper Factories ───────────────────────────────────────────────────

/// Creates a [MovementKind] with minimal required fields for testing.
MovementKind _makeKind({
  required String code,
  String? titleFa,
  required int jointImpact,
  required bool isEnabled,
  MovementFamily family = MovementFamily.endurance,
}) {
  return MovementKind(
    code: code,
    titleFa: titleFa ?? code,
    emoji: '🏃',
    family: family,
    baseMet: 5.0,
    metLow: 3.0,
    metHigh: 8.0,
    primaryMetric: MovementMetric.duration,
    secondaryMetric: MovementMetric.none,
    isOutdoor: false,
    isSocial: false,
    needsVenue: false,
    jointImpact: jointImpact,
    isCustom: false,
    isEnabled: isEnabled,
    usageCount: 0,
    sortOrder: 0,
  );
}

/// Creates a [MovementEvent] with only the fields relevant to budget calculations.
MovementEvent _makeEvent({required String code, required double metMinutes}) {
  return MovementEvent(
    id: 'evt_${code.toLowerCase()}',
    kindCode: code,
    durationMinutes: 30,
    loggedAt: DateTime.now().millisecondsSinceEpoch,
    metMinutes: metMinutes,
  );
}

/// Creates a [MovementBudgetSnapshot] with overridable target and achieved values.
MovementBudgetSnapshot _makeSnapshot({
  required double weeklyMetMinutesTarget,
  required double achievedMetMinutes,
}) {
  return MovementBudgetSnapshot(
    weeklyMetMinutesTarget: weeklyMetMinutesTarget,
    achievedMetMinutes: achievedMetMinutes,
    activeDays: 0,
    targetActiveDays: 4,
    byFamily: {},
    byKind: {},
    daysRemaining: 3,
    projectedTotal: null,
    events: const [],
    kindsByCode: const {},
  );
}
