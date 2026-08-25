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
  });
}
