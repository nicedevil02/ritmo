import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('MvMovementKind Roundtrip & Model Verification (S1-T1)', () {
    test('FOOTBALL seed row roundtrip and aliasList', () {
      const football = MvMovementKind(
        code: 'FOOTBALL',
        titleFa: 'فوتبال',
        emoji: '⚽',
        family: MovementFamily.sport,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: null,
        isOutdoor: false,
        isSocial: true,
        needsVenue: true,
        seasonMask: null,
        jointImpact: 2,
        aliasesFa: 'فوتبال,توپ بازی',
        isCustom: false,
        isEnabled: true,
        usageCount: 5,
        lastUsedAt: null,
        sortOrder: 1,
        sessionModeOverride: null,
      );

      expect(football.aliasList, equals(['فوتبال', 'توپ بازی']));

      final map = football.toMap();
      final fromMap = MvMovementKind.fromMap(map);

      expect(fromMap.code, equals('FOOTBALL'));
      expect(fromMap.titleFa, equals('فوتبال'));
      expect(fromMap.emoji, equals('⚽'));
      expect(fromMap.family, equals(MovementFamily.sport));
      expect(fromMap.baseMet, equals(7.0));
      expect(fromMap.isSocial, isTrue);
      expect(fromMap.aliasList, equals(['فوتبال', 'توپ بازی']));
    });

    test('HIKING seed row roundtrip and aliasList', () {
      const hiking = MvMovementKind(
        code: 'HIKING',
        titleFa: 'کوه‌نوردی',
        emoji: '🏔',
        family: MovementFamily.outdoor,
        baseMet: 6.0,
        metLow: 4.5,
        metHigh: 8.5,
        primaryMetric: MovementMetric.distance,
        secondaryMetric: MovementMetric.elevation,
        isOutdoor: true,
        isSocial: false,
        needsVenue: false,
        seasonMask: '1,2,3,7,8,9',
        jointImpact: 2,
        aliasesFa: 'کوهنوردی,کوه,پیاده روی کوه',
        isCustom: false,
        isEnabled: true,
        usageCount: 2,
        lastUsedAt: null,
        sortOrder: 12,
        sessionModeOverride: null,
      );

      expect(hiking.aliasList, equals(['کوهنوردی', 'کوه', 'پیاده روی کوه']));

      final map = hiking.toMap();
      final fromMap = MvMovementKind.fromMap(map);

      expect(fromMap.code, equals('HIKING'));
      expect(fromMap.family, equals(MovementFamily.outdoor));
      expect(fromMap.primaryMetric, equals(MovementMetric.distance));
      expect(fromMap.secondaryMetric, equals(MovementMetric.elevation));
      expect(fromMap.isOutdoor, isTrue);
      expect(fromMap.seasonMask, equals('1,2,3,7,8,9'));
      expect(fromMap.aliasList, equals(['کوهنوردی', 'کوه', 'پیاده روی کوه']));
    });

    test('STRETCHING seed row roundtrip and aliasList', () {
      const stretching = MvMovementKind(
        code: 'STRETCHING',
        titleFa: 'کشش',
        emoji: '🤸',
        family: MovementFamily.mindBody,
        baseMet: 2.3,
        metLow: 1.8,
        metHigh: 3.0,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: null,
        isOutdoor: false,
        isSocial: false,
        needsVenue: false,
        seasonMask: null,
        jointImpact: 0,
        aliasesFa: 'کشش,انعطاف,گرم کردن',
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        lastUsedAt: null,
        sortOrder: 20,
        sessionModeOverride: null,
      );

      expect(stretching.aliasList, equals(['کشش', 'انعطاف', 'گرم کردن']));

      final map = stretching.toMap();
      final fromMap = MvMovementKind.fromMap(map);

      expect(fromMap.code, equals('STRETCHING'));
      expect(fromMap.family, equals(MovementFamily.mindBody));
      expect(fromMap.baseMet, equals(2.3));
      expect(fromMap.jointImpact, equals(0));
      expect(fromMap.aliasList, equals(['کشش', 'انعطاف', 'گرم کردن']));
    });
  });
}
