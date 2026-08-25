import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/mv_commitment.dart';

void main() {
  group('MvCommitment Model Verification (S2-T2)', () {
    test('Valid MvCommitment creation and property access', () {
      final commitment = MvCommitment(
        id: 1,
        kindCode: 'FUTSAL',
        titleFa: 'فوتسال پنجشنبه‌ها',
        dayOfWeekSat0: 5,
        startTime: '21:00',
        durationMinutes: 90,
        venueNote: 'سالن یادگار',
        partnerNote: 'تیم بچه‌های دانشگاه',
        recurrence: CommitmentRecurrence.weekly,
        isActive: true,
        isFlexible: false,
        startDateIso: '2026-08-01',
        endDateIso: null,
        reminderMinutes: 60,
      );

      expect(commitment.id, equals(1));
      expect(commitment.kindCode, equals('FUTSAL'));
      expect(commitment.titleFa, equals('فوتسال پنجشنبه‌ها'));
      expect(commitment.dayOfWeekSat0, equals(5));
      expect(commitment.persianWeekdayName, equals('پنج‌شنبه'));
      expect(commitment.startTime, equals('21:00'));
      expect(commitment.durationMinutes, equals(90));
      expect(commitment.recurrence, equals(CommitmentRecurrence.weekly));
      expect(commitment.isActive, isTrue);
      expect(commitment.isFlexible, isFalse);
    });

    test('Roundtrip serialization: toMap and fromMap', () {
      final original = MvCommitment(
        id: 42,
        kindCode: 'SWIMMING',
        titleFa: 'استخر صبح جمعه',
        dayOfWeekSat0: 6,
        startTime: '08:30',
        durationMinutes: 60,
        venueNote: 'استخر آزادی',
        partnerNote: null,
        recurrence: CommitmentRecurrence.biweekly,
        isActive: true,
        isFlexible: true,
        startDateIso: '2026-08-01',
        endDateIso: '2026-12-29',
        reminderMinutes: 30,
        createdAt: '2026-08-01T10:00:00.000',
        updatedAt: '2026-08-01T10:00:00.000',
      );

      final map = original.toMap();
      final reconstructed = MvCommitment.fromMap(map);

      expect(reconstructed, equals(original));
      expect(reconstructed.persianWeekdayName, equals('جمعه'));
      expect(reconstructed.recurrence, equals(CommitmentRecurrence.biweekly));
      expect(reconstructed.isFlexible, isTrue);
    });

    test('Persian weekdays mapping for 0..6', () {
      final expected = [
        'شنبه',
        'یک‌شنبه',
        'دوشنبه',
        'سه‌شنبه',
        'چهارشنبه',
        'پنج‌شنبه',
        'جمعه',
      ];

      for (int i = 0; i < 7; i++) {
        final c = MvCommitment(
          kindCode: 'WALKING',
          dayOfWeekSat0: i,
          startTime: '07:00',
          durationMinutes: 30,
        );
        expect(c.persianWeekdayName, equals(expected[i]));
      }
    });

    test('Throws ArgumentError for invalid dayOfWeekSat0', () {
      expect(
        () => MvCommitment(
          kindCode: 'WALKING',
          dayOfWeekSat0: -1,
          startTime: '07:00',
          durationMinutes: 30,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => MvCommitment(
          kindCode: 'WALKING',
          dayOfWeekSat0: 7,
          startTime: '07:00',
          durationMinutes: 30,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Throws ArgumentError for invalid startTime', () {
      expect(
        () => MvCommitment(
          kindCode: 'WALKING',
          dayOfWeekSat0: 0,
          startTime: '7:00', // Must be 2 digits
          durationMinutes: 30,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => MvCommitment(
          kindCode: 'WALKING',
          dayOfWeekSat0: 0,
          startTime: '25:00', // Invalid hour
          durationMinutes: 30,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => MvCommitment(
          kindCode: 'WALKING',
          dayOfWeekSat0: 0,
          startTime: '12:60', // Invalid minute
          durationMinutes: 30,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Throws ArgumentError for invalid durationMinutes', () {
      expect(
        () => MvCommitment(
          kindCode: 'WALKING',
          dayOfWeekSat0: 0,
          startTime: '07:00',
          durationMinutes: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => MvCommitment(
          kindCode: 'WALKING',
          dayOfWeekSat0: 0,
          startTime: '07:00',
          durationMinutes: -15,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('copyWith updates fields without mutating original', () {
      final original = MvCommitment(
        id: 10,
        kindCode: 'TENNIS',
        dayOfWeekSat0: 2,
        startTime: '18:00',
        durationMinutes: 60,
      );

      final updated = original.copyWith(
        durationMinutes: 75,
        venueNote: 'زمین شماره ۲',
        isFlexible: true,
      );

      expect(updated.durationMinutes, equals(75));
      expect(updated.venueNote, equals('زمین شماره ۲'));
      expect(updated.isFlexible, isTrue);
      expect(original.durationMinutes, equals(60));
      expect(original.venueNote, isNull);
      expect(original.isFlexible, isFalse);
    });

    test('occursOnWeek correctly filters weekly and biweekly recurrence', () {
      final weekly = MvCommitment(
        kindCode: 'FUTSAL',
        dayOfWeekSat0: 5,
        startTime: '21:00',
        durationMinutes: 90,
        recurrence: CommitmentRecurrence.weekly,
      );

      final biweekly = MvCommitment(
        kindCode: 'FUTSAL',
        dayOfWeekSat0: 5,
        startTime: '21:00',
        durationMinutes: 90,
        recurrence: CommitmentRecurrence.biweekly,
      );

      expect(weekly.occursOnWeek(1), isTrue);
      expect(weekly.occursOnWeek(2), isTrue);

      expect(biweekly.occursOnWeek(1), isFalse); // Odd week -> does not occur
      expect(biweekly.occursOnWeek(2), isTrue);  // Even week -> occurs
      expect(biweekly.occursOnWeek(3), isFalse);
      expect(biweekly.occursOnWeek(4), isTrue);
    });

    test('nextOccurrenceAfter computes next occurrence correctly', () {
      // پنجشنبه ساعت ۲۱:۰۰ (dayOfWeekSat0 = 5)
      final futsalThu = MvCommitment(
        kindCode: 'FUTSAL',
        dayOfWeekSat0: 5,
        startTime: '21:00',
        durationMinutes: 90,
      );

      // چهارشنبه ۲۰۲۶/۰۸/۲۶ ساعت ۱۰:۰۰ (Wednesday)
      final wednesday = DateTime(2026, 8, 26, 10, 0);
      final nextFromWed = futsalThu.nextOccurrenceAfter(wednesday);
      expect(nextFromWed, isNotNull);
      expect(nextFromWed!.weekday, equals(DateTime.thursday));
      expect(nextFromWed.day, equals(27));
      expect(nextFromWed.hour, equals(21));
      expect(nextFromWed.minute, equals(0));

      // جمعه ۲۰۲۶/۰۸/۲۸ ساعت ۱۰:۰۰ (Friday)
      final friday = DateTime(2026, 8, 28, 10, 0);
      final nextFromFri = futsalThu.nextOccurrenceAfter(friday);
      expect(nextFromFri, isNotNull);
      expect(nextFromFri!.weekday, equals(DateTime.thursday));
      expect(nextFromFri.day, equals(3)); // Next week's Thursday (Sep 3)
      expect(nextFromFri.month, equals(9));
      expect(nextFromFri.hour, equals(21));

      // همان روز پنجشنبه ۲۰۲۶/۰۸/۲۷ ساعت ۲۰:۰۰ (قبل از ۲۱:۰۰)
      final thuBefore = DateTime(2026, 8, 27, 20, 0);
      final nextFromThuBefore = futsalThu.nextOccurrenceAfter(thuBefore);
      expect(nextFromThuBefore, isNotNull);
      expect(nextFromThuBefore!.day, equals(27));
      expect(nextFromThuBefore.hour, equals(21));

      // همان روز پنجشنبه ۲۰۲۶/۰۸/۲۷ ساعت ۲۲:۰۰ (بعد از ۲۱:۰۰)
      final thuAfter = DateTime(2026, 8, 27, 22, 0);
      final nextFromThuAfter = futsalThu.nextOccurrenceAfter(thuAfter);
      expect(nextFromThuAfter, isNotNull);
      expect(nextFromThuAfter!.day, equals(3)); // Next Thursday
      expect(nextFromThuAfter.month, equals(9));
    });
  });
}
