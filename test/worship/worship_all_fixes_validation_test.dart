import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/worship/logic/qibla.dart';
import 'package:ritmo/features/worship/logic/hijri_calendar.dart';
import 'package:ritmo/features/worship/logic/prayer_times.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:ritmo/core/services/prayer_time_provider.dart';

void main() {
  group('Worship 17-Fixes Comprehensive Validation Tests', () {

    test('1. C5 & C6: ihtiyatMinutes and local computation prevents fake 00:00', () {
      final date = DateTime(2026, 8, 25);
      final rawTimes = PrayerTimeProvider.instance.computePrayerTimesLocally(
        latitude: 35.6892,
        longitude: 51.3890,
        calcMethodStr: 'TEHRAN_GEOPHYSICS',
        date: date,
        ihtiyatMinutes: 0,
      );

      final ihtiyatTimes = PrayerTimeProvider.instance.computePrayerTimesLocally(
        latitude: 35.6892,
        longitude: 51.3890,
        calcMethodStr: 'TEHRAN_GEOPHYSICS',
        date: date,
        ihtiyatMinutes: 5,
      );

      expect(rawTimes['fajr'], isNotNull);
      expect(rawTimes['fajr'], isNot(equals('00:00')));
      expect(ihtiyatTimes['fajr'], isNotNull);
      expect(ihtiyatTimes['fajr'], isNot(equals('00:00')));
      expect(rawTimes['dhuhr'], isNot(equals('00:00')));
      expect(rawTimes['maghrib'], isNot(equals('00:00')));

      // Parse Fajr minutes to ensure 5 minutes difference
      final rawFajrMin = int.parse(rawTimes['fajr']!.split(':')[0]) * 60 + int.parse(rawTimes['fajr']!.split(':')[1]);
      final ihtiyatFajrMin = int.parse(ihtiyatTimes['fajr']!.split(':')[0]) * 60 + int.parse(ihtiyatTimes['fajr']!.split(':')[1]);
      expect(ihtiyatFajrMin, equals(rawFajrMin + 5));
    });

    test('2. H3 & M11: WorshipPracticeState is 100% derived from completions', () {
      final practice = WorshipPractice(
        id: 'wp_fajr',
        practiceType: 'PRAYER',
        title: 'نماز صبح',
        dailyTarget: 1,
        dailyDone: 0,
        sortOrder: 1,
        isActive: true,
        createdAt: 1000,
        updatedAt: 1000,
      );

      final doneState = WorshipPracticeState(
        practice: practice,
        dateStr: '2026-08-25',
        countDone: 1,
        countTarget: 1,
        resultType: 'DONE',
        quality: 'ON_TIME',
      );

      expect(doneState.isDone, isTrue);
      expect(doneState.isPending, isFalse);
      expect(doneState.isSkipped, isFalse);
      expect(doneState.isQada, isFalse);
      expect(doneState.quality, equals('ON_TIME'));

      final qadaState = WorshipPracticeState(
        practice: practice,
        dateStr: '2026-08-25',
        countDone: 1,
        countTarget: 1,
        resultType: 'QADA_ADDED',
        quality: 'QADA',
      );

      expect(qadaState.isQada, isTrue);
      expect(qadaState.isDone, isFalse);
    });

    test('3. H5 & H7: WorshipSeason.isActiveNow supports lunar night transition and unified aliases', () {
      final nightSeason = WorshipSeason(
        id: 'ghadr_nights',
        seasonType: 'GHADR',
        title: 'شب‌های قدر',
        startDate: '19',
        endDate: '23',
        calendar: 'HIJRI',
        isActive: true,
        priorityWeight: 1,
        createdAt: 1000,
        recurrence: 'NIGHTS_OF_HIJRI_MONTH',
        dayList: '[19, 21, 23]',
        hijriMonth: 9, // Ramadan
      );

      final times = PrayerTimes(
        date: '2026-04-06',
        cityId: 'TEHRAN',
        fajr: DateTime(2026, 4, 6, 4, 30),
        sunrise: DateTime(2026, 4, 6, 6, 0),
        dhuhr: DateTime(2026, 4, 6, 12, 10),
        asr: DateTime(2026, 4, 6, 16, 0),
        maghrib: DateTime(2026, 4, 6, 18, 30),
        sunset: DateTime(2026, 4, 6, 18, 10),
        isha: DateTime(2026, 4, 6, 19, 30),
        midnightShari: DateTime(2026, 4, 6, 23, 40),
        calculationMethod: 'TEHRAN_GEOPHYSICS',
      );

      // On Ramadan 18 before maghrib -> NOT 19th night yet
      final beforeMaghrib = DateTime(2026, 4, 6, 17, 0);
      const h18 = HijriDate(day: 18, month: 9, year: 1447, monthName: 'رمضان', formatted: '۱۸ رمضان');
      expect(nightSeason.isActiveNow(h18, beforeMaghrib, times), isFalse);

      // On Ramadan 18 after maghrib -> 19th night has started!
      final afterMaghrib = DateTime(2026, 4, 6, 19, 0);
      expect(nightSeason.isActiveNow(h18, afterMaghrib, times), isTrue);

      // Solar date range alias check
      final solarSeason = WorshipSeason(
        id: 'nowruz',
        seasonType: 'NOWRUZ',
        title: 'نوروز',
        startDate: '01-01',
        endDate: '01-13',
        calendar: 'SOLAR',
        isActive: true,
        priorityWeight: 1,
        createdAt: 1000,
        recurrence: 'RANGE_SOLAR',
      );

      final nowruzDay = DateTime(2026, 3, 25); // Farvardin 5
      expect(solarSeason.isActiveNow(null, nowruzDay), isTrue);
    });

    test('4. H11 & N5 (Fiqh Invariant): Fasting in menstruation creates Qada debt, prayer does not', () {
      final prayerPractice = WorshipPractice(
        id: 'wp_dhuhr',
        practiceType: 'PRAYER',
        title: 'نماز ظهر',
        dailyTarget: 1,
        dailyDone: 0,
        sortOrder: 1,
        isActive: true,
        allowQada: true,
        createdAt: 1000,
        updatedAt: 1000,
      );

      final fastingPractice = WorshipPractice(
        id: 'wp_ramadan_fasting',
        practiceType: 'FASTING',
        title: 'روزه واجب',
        dailyTarget: 1,
        dailyDone: 0,
        sortOrder: 1,
        isActive: true,
        allowQada: true,
        createdAt: 1000,
        updatedAt: 1000,
      );

      final menstruationCtx = WorshipDayContext(
        date: DateTime(2026, 8, 25),
        prayerExempt: true,
        fastingExempt: true,
        reason: 'MENSTRUATION',
      );

      // Prayer during menstruation: EXEMPT, shouldAddQada = false, result = SKIPPED
      expect(
        WorshipEngine.shouldAddQada(
          practice: prayerPractice,
          ctx: menstruationCtx,
          suspended: true,
        ),
        isFalse,
      );
      expect(
        WorshipEngine.resolveMissResult(
          practice: prayerPractice,
          ctx: menstruationCtx,
          suspended: true,
        ),
        equals('SKIPPED'),
      );

      // Fasting during menstruation: MUST BE MADE UP LATER, shouldAddQada = true, result = QADA_ADDED
      expect(
        WorshipEngine.shouldAddQada(
          practice: fastingPractice,
          ctx: menstruationCtx,
          suspended: true,
        ),
        isTrue,
      );
      expect(
        WorshipEngine.resolveMissResult(
          practice: fastingPractice,
          ctx: menstruationCtx,
          suspended: true,
        ),
        equals('QADA_ADDED'),
      );
    });

    test('5. M12: WorshipDebt progressPercent handles totalCount == 0 without NaN or 100%', () {
      final debtZero = WorshipDebt(
        id: 'debt_PRAYER_wp_fajr',
        debtType: 'PRAYER',
        title: 'نماز صبح',
        totalCount: 0,
        remainingCount: 0,
        dailyTarget: 1,
        autoCreated: true,
        isArchived: false,
        createdAt: 1000,
        updatedAt: 1000,
      );

      expect(debtZero.progressPercent, equals(0.0));

      final debtHalf = WorshipDebt(
        id: 'debt_PRAYER_wp_fajr',
        debtType: 'PRAYER',
        title: 'نماز صبح',
        totalCount: 10,
        remainingCount: 5,
        dailyTarget: 1,
        autoCreated: true,
        isArchived: false,
        createdAt: 1000,
        updatedAt: 1000,
      );

      expect(debtHalf.progressPercent, equals(50.0));
    });

    test('6. Magnetic Declination: True North and Qibla Bearing calculation', () {
      // Tehran coordinates (Lat: 35.6892, Lon: 51.3890)
      final declination = magneticDeclination(35.6892, 51.3890);
      expect(declination, inInclusiveRange(1.0, 7.0));

      final trueBearing = qiblaBearing(35.6892, 51.3890);
      expect(trueBearing, inInclusiveRange(210.0, 225.0));


      final magBearing = magneticQiblaBearing(35.6892, 51.3890);
      expect(magBearing, equals((trueBearing - declination + 360.0) % 360.0));
    });

    test('7. Future Date Guard: WorshipEngine.logDone blocks future date logs', () async {
      final futureDate = DateTime.now().add(const Duration(days: 2));
      final res = await WorshipEngine.instance.logDone(
        practiceId: 'wp_tasbih',
        date: futureDate,
      );

      expect(res, isA<WorshipLogBlocked>());
      final blocked = res as WorshipLogBlocked;
      expect(blocked.reasonCode, equals('NOT_YET_DUE'));
    });

  });
}
