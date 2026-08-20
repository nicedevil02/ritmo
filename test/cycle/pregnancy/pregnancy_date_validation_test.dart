import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';

void main() {
  group('PregnancyDateValidation Tests (PRG-08)', () {
    final referenceNow = DateTime(2026, 6, 1);

    test('1. Negative: futureLmp error when LMP is in the future', () {
      final lmp = DateTime(2026, 6, 10);
      final edd = DateTime(2027, 3, 17);

      final res = PregnancyDateEngine.validatePregnancyDates(
        lmp: lmp,
        edd: edd,
        now: referenceNow,
      );

      expect(res.isValid, isFalse);
      expect(res.errorCode, equals(PregnancyDateErrorCode.futureLmp));
      expect(res.errorMessageFa, contains('آینده'));
    });

    test(
      '2. Negative: eddBeforeLmp error when EDD is not strictly after LMP',
      () {
        final lmp = DateTime(2026, 2, 1);
        final edd = DateTime(2026, 1, 15);

        final res = PregnancyDateEngine.validatePregnancyDates(
          lmp: lmp,
          edd: edd,
          now: referenceNow,
        );

        expect(res.isValid, isFalse);
        expect(res.errorCode, equals(PregnancyDateErrorCode.eddBeforeLmp));
        expect(res.errorMessageFa, contains('بعد از تاریخ شروع'));
      },
    );

    test('3. Negative: invalidGestationSpan when span is < 240 days', () {
      final lmp = DateTime(2026, 2, 1);
      final edd = DateTime(2026, 7, 1); // 150 days

      final res = PregnancyDateEngine.validatePregnancyDates(
        lmp: lmp,
        edd: edd,
        now: referenceNow,
      );

      expect(res.isValid, isFalse);
      expect(
        res.errorCode,
        equals(PregnancyDateErrorCode.invalidGestationSpan),
      );
      expect(res.errorMessageFa, contains('۲۴۰ تا ۳۰۰'));
    });

    test('4. Negative: invalidGestationSpan when span is > 300 days', () {
      final lmp = DateTime(2026, 2, 1);
      final edd = DateTime(2027, 2, 1); // 365 days

      final res = PregnancyDateEngine.validatePregnancyDates(
        lmp: lmp,
        edd: edd,
        now: referenceNow,
      );

      expect(res.isValid, isFalse);
      expect(
        res.errorCode,
        equals(PregnancyDateErrorCode.invalidGestationSpan),
      );
    });

    test(
      '5. Negative: gestationExceeds42Weeks when gestation is > 42 weeks',
      () {
        final lmp = DateTime(
          2025,
          7,
          1,
        ); // > 300 days ago relative to 2026-06-01
        final edd = DateTime(2026, 4, 7); // 280 days after LMP

        final res = PregnancyDateEngine.validatePregnancyDates(
          lmp: lmp,
          edd: edd,
          now: referenceNow,
        );

        expect(res.isValid, isFalse);
        expect(
          res.errorCode,
          equals(PregnancyDateErrorCode.gestationExceeds42Weeks),
        );
        expect(res.errorMessageFa, contains('۴۲ هفته'));
      },
    );

    test('6. Positive: Normal valid dates within acceptable boundaries', () {
      final lmp = DateTime(2026, 2, 1);
      final edd = DateTime(2026, 11, 8); // exactly 280 days, now is ~120 days

      final res = PregnancyDateEngine.validatePregnancyDates(
        lmp: lmp,
        edd: edd,
        now: referenceNow,
      );

      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
      expect(res.errorMessageFa, isNull);
    });
  });
}
