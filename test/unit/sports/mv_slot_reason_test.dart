import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('MvSlot & MvReasonKeys Guard Tests (S3-T3)', () {
    test(
      'Every slot produced by PlanEngine has a valid non-null reasonKey from whitelist',
      () {
        const planEngine = PlanEngine();
        final profile = MvUserProfile.empty().copyWith(trainingDays: [0, 2, 4]);

        final decision = planEngine.generateWeekPlan(
          profile: profile,
          weekSaturday: DateTime.parse('2026-08-22'),
        );

        expect(decision.value.length, equals(7));
        expect(decision.reasonKey, isNotNull);
        expect(MvReasonKeys.all.contains(decision.reasonKey), isTrue);

        for (final slot in decision.value) {
          // Acceptance Guard Test: reasonKey must never be null and must be in whitelist
          expect(
            slot.reasonKey,
            isNotNull,
            reason: 'Slot ${slot.id} has null reasonKey',
          );
          expect(
            MvReasonKeys.all.contains(slot.reasonKey),
            isTrue,
            reason: 'Slot ${slot.id} has unknown reasonKey: ${slot.reasonKey}',
          );
        }
      },
    );

    test(
      'Locked anchor slot preserved by PlanEngine retains valid reasonKey',
      () {
        const lockedSlot = MvSlot(
          id: 'slot_thur',
          dateIso: '2026-08-27',
          slotType: MvSlotType.sport,
          kindCode: 'FUTSAL',
          headlineFa: 'فوتسال',
          isLocked: true,
          reasonKey: MvReasonKeys.anchor,
          createdAt: 100,
          updatedAt: 100,
        );

        const planEngine = PlanEngine();
        final profile = MvUserProfile.empty().copyWith(trainingDays: [1, 3, 5]);

        final decision = planEngine.generateWeekPlan(
          profile: profile,
          weekSaturday: DateTime.parse('2026-08-22'),
          existingSlots: [lockedSlot],
        );

        final preserved = decision.value.firstWhere(
          (s) => s.dateIso == '2026-08-27',
        );
        expect(preserved.reasonKey, equals(MvReasonKeys.anchor));
        expect(MvReasonKeys.all.contains(preserved.reasonKey), isTrue);
      },
    );

    test(
      'MvSlot toMap and fromMap roundtrip serializes reasonKey and reasonParams accurately',
      () {
        const slot = MvSlot(
          id: 'slot_test_1',
          dateIso: '2026-08-23',
          headlineFa: 'تمرین جبرانی',
          reasonKey: MvReasonKeys.complement,
          reasonParams: {'kind': 'فوتسال', 'focus': 'زنجیره خلفی'},
          createdAt: 100,
          updatedAt: 100,
        );

        final map = slot.toMap();
        expect(map['reasonKey'], equals(MvReasonKeys.complement));
        expect(map['reasonParams'], isA<String>()); // Serialized JSON string

        final restored = MvSlot.fromMap(map);
        expect(restored.reasonKey, equals(MvReasonKeys.complement));
        expect(
          restored.reasonParams,
          equals({'kind': 'فوتسال', 'focus': 'زنجیره خلفی'}),
        );
        expect(restored, equals(slot));
      },
    );

    test(
      'MvReasonKeys.formatReasonFa replaces template parameters with exact strings',
      () {
        expect(
          MvReasonKeys.formatReasonFa(MvReasonKeys.anchor),
          equals('لنگر ثابت توست'),
        );
        expect(
          MvReasonKeys.formatReasonFa(MvReasonKeys.preAnchorTaper, {
            'kind': 'فوتسال',
          }),
          equals('فردا فوتسال داری، امروز سبک'),
        );
        expect(
          MvReasonKeys.formatReasonFa(MvReasonKeys.postAnchorRecovery, {
            'kind': 'شنا',
          }),
          equals('دیروز شنا داشتی، امروز بازیابی'),
        );
        expect(
          MvReasonKeys.formatReasonFa(MvReasonKeys.complement, {
            'kind': 'کوهنوردی',
            'focus': 'چهارسر',
          }),
          equals('پشتیبانی کوهنوردی: تقویت چهارسر'),
        );
        expect(
          MvReasonKeys.formatReasonFa(MvReasonKeys.whoGap, {'remaining': '۴۵'}),
          equals('برای رسیدن به هدف هفتگی ۴۵ دقیقه مانده'),
        );
        expect(
          MvReasonKeys.formatReasonFa(MvReasonKeys.strengthQuota, {
            'days': '۲',
          }),
          equals('این هفته فقط ۲ روز قدرتی داشتی'),
        );
      },
    );
  });
}
