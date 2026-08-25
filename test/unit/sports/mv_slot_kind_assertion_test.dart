import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('MvSlotType & MvSlot kindCode Assertion Verification (S1-T4)', () {
    test('MvSlotType contains sport and outdoor with correct codes and titles', () {
      expect(MvSlotType.sport.code, equals('SPORT'));
      expect(MvSlotType.sport.titleFa, equals('ورزش و بازی'));
      expect(MvSlotType.fromCode('SPORT'), equals(MvSlotType.sport));

      expect(MvSlotType.outdoor.code, equals('OUTDOOR'));
      expect(MvSlotType.outdoor.titleFa, equals('طبیعت و فضای باز'));
      expect(MvSlotType.fromCode('OUTDOOR'), equals(MvSlotType.outdoor));
    });

    test('Creating MvSlot with slotType.sport and kindCode == null throws AssertionError', () {
      expect(
        () => MvSlot(
          id: 'test_sport_invalid',
          dateIso: '2026-08-25',
          slotType: MvSlotType.sport,
          kindCode: null,
          headlineFa: 'ورزش بدون نوع',
          createdAt: 1000,
          updatedAt: 1000,
        ),
        throwsAssertionError,
      );
    });

    test('Creating MvSlot with slotType.outdoor and kindCode == null throws AssertionError', () {
      expect(
        () => MvSlot(
          id: 'test_outdoor_invalid',
          dateIso: '2026-08-25',
          slotType: MvSlotType.outdoor,
          kindCode: null,
          headlineFa: 'طبیعت بدون نوع',
          createdAt: 1000,
          updatedAt: 1000,
        ),
        throwsAssertionError,
      );
    });

    test('Creating MvSlot with slotType.cardio and kindCode == null throws AssertionError', () {
      expect(
        () => MvSlot(
          id: 'test_cardio_invalid',
          dateIso: '2026-08-25',
          slotType: MvSlotType.cardio,
          kindCode: null,
          headlineFa: 'هوازی بدون نوع',
          createdAt: 1000,
          updatedAt: 1000,
        ),
        throwsAssertionError,
      );
    });

    test('Creating MvSlot with valid kindCode succeeds for sport, outdoor, cardio, and strength', () {
      final sportSlot = MvSlot(
        id: 'test_sport_valid',
        dateIso: '2026-08-25',
        slotType: MvSlotType.sport,
        kindCode: 'FOOTBALL',
        headlineFa: 'فوتبال',
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(sportSlot.kindCode, equals('FOOTBALL'));

      final outdoorSlot = MvSlot(
        id: 'test_outdoor_valid',
        dateIso: '2026-08-25',
        slotType: MvSlotType.outdoor,
        kindCode: 'HIKING',
        headlineFa: 'کوهنوردی',
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(outdoorSlot.kindCode, equals('HIKING'));

      final strengthSlot = MvSlot(
        id: 'test_strength_valid',
        dateIso: '2026-08-25',
        slotType: MvSlotType.strength,
        kindCode: null, // Valid for strength
        headlineFa: 'تمرین قدرتی',
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(strengthSlot.kindCode, isNull);
    });
  });
}
