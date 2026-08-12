// test/supplementary_sports/movement_phase_4_test.dart
//
// تست‌های واحد فاز ۴: اسکلت مشترک و استنتاج ۶ حالت اجرا

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/session_mode.dart';

void main() {
  group('Phase 4 | SessionMode Inference Tests', () {
    test('resolveMode infers strength as structured', () {
      const kind = MovementKind(
        code: 'STRENGTH_TEST',
        titleFa: 'تست قدرت',
        emoji: '🏋️',
        family: MovementFamily.strength,
        baseMet: 5.0,
        metLow: 3.0,
        metHigh: 7.0,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: false,
        needsVenue: false,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );

      expect(resolveMode(kind), equals(SessionMode.structured));
    });

    test('resolveMode infers social sports as match', () {
      const kind = MovementKind(
        code: 'SOCCER_TEST',
        titleFa: 'تست فوتبال',
        emoji: '⚽',
        family: MovementFamily.sport,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true,
        isSocial: true, // social sport -> match mode
        needsVenue: true,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );

      expect(resolveMode(kind), equals(SessionMode.match));
    });

    test('resolveMode infers laps metric as laps', () {
      const kind = MovementKind(
        code: 'SWIM_TEST',
        titleFa: 'تست شنا',
        emoji: '🏊',
        family: MovementFamily.endurance,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
        primaryMetric: MovementMetric.laps, // laps metric -> laps mode
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: false,
        needsVenue: true,
        jointImpact: 0,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );

      expect(resolveMode(kind), equals(SessionMode.laps));
    });

    test('resolveMode infers outdoor distance sports as route (hiking/trail)', () {
      const kind = MovementKind(
        code: 'HIKE_TEST',
        titleFa: 'تست کوهنوردی',
        emoji: '🏔',
        family: MovementFamily.outdoor,
        baseMet: 6.0,
        metLow: 4.0,
        metHigh: 8.0,
        primaryMetric: MovementMetric.distance,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true, // outdoor + distance -> route
        isSocial: false,
        needsVenue: false,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );

      expect(resolveMode(kind), equals(SessionMode.route));
    });

    test('resolveMode infers indoor distance sports as distance (walking/running)', () {
      const kind = MovementKind(
        code: 'WALK_TEST',
        titleFa: 'تست پیاده روی',
        emoji: '🚶',
        family: MovementFamily.endurance,
        baseMet: 3.0,
        metLow: 2.0,
        metHigh: 4.0,
        primaryMetric: MovementMetric.distance, // indoor distance -> distance mode
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: false,
        needsVenue: false,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );

      expect(resolveMode(kind), equals(SessionMode.distance));
    });

    test('effectiveMode uses sessionModeOverride when present', () {
      const kind = MovementKind(
        code: 'YOGA_TEST',
        titleFa: 'تست یوگا',
        emoji: '🧘',
        family: MovementFamily.mindBody,
        baseMet: 2.5,
        metLow: 2.0,
        metHigh: 3.0,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: false,
        needsVenue: false,
        jointImpact: 0,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
        sessionModeOverride: 'MATCH', // overridden from timed to match!
      );

      expect(effectiveMode(kind), equals(SessionMode.match));
    });

    test('MovementKind serializes and deserializes sessionModeOverride correctly', () {
      final kind = MovementKind.fromMap({
        'code': 'CUSTOM_KIND',
        'titleFa': 'سفارشی',
        'emoji': '🥋',
        'family': 'MARTIAL_SKILL',
        'baseMet': 8.0,
        'metLow': 6.0,
        'metHigh': 10.0,
        'primaryMetric': 'DURATION',
        'secondaryMetric': 'NONE',
        'isOutdoor': 0,
        'isSocial': 0,
        'needsVenue': 0,
        'jointImpact': 1,
        'isCustom': 1,
        'isEnabled': 1,
        'usageCount': 5,
        'sortOrder': 10,
        'sessionModeOverride': 'LAPS',
      });

      expect(kind.sessionModeOverride, equals('LAPS'));
      final map = kind.toMap();
      expect(map['sessionModeOverride'], equals('LAPS'));
    });

    test('manual liveJson updates are stored correctly in Map format', () {
      final live = <String, dynamic>{};
      live['manualDistanceMeters'] = 1500.0;
      live['manualElevationMeters'] = 350.0;

      final liveJson = jsonEncode(live);
      final decoded = jsonDecode(liveJson) as Map<String, dynamic>;

      expect(decoded['manualDistanceMeters'], equals(1500.0));
      expect(decoded['manualElevationMeters'], equals(350.0));
    });
  });
}
