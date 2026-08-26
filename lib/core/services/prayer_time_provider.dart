import 'package:adhan/adhan.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/services/online_prayer_time_service.dart';
import 'package:sqflite/sqflite.dart';

class PrayerTimeProvider {
  PrayerTimeProvider._init();
  static final PrayerTimeProvider instance = PrayerTimeProvider._init();

  Future<Map<String, String>> getPrayerTimesForDate({
    required String cityId,
    required DateTime date,
    bool forceOnline = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);

    final settingsResult = await db.query('app_settings');
    final settings = {
      for (final row in settingsResult)
        row['key']! as String: row['value']! as String,
    };

    final calcMethodStr =
        settings['prayer_calculation_method'] ?? 'TEHRAN_GEOPHYSICS';
    final ihtiyatMinutes = int.tryParse(settings['ihtiyat_minutes'] ?? '0') ?? 0;

    // 1. Fetch coordinates: check for custom/GPS settings, otherwise query iran_cities
    var latitude = 35.6892; // default Tehran
    var longitude = 51.3890;

    if (cityId.startsWith('CUSTOM_') || settings['prayer_location_mode'] == 'CUSTOM_COORDS') {
      final customLat = double.tryParse(settings['prayer_custom_lat'] ?? '');
      final customLng = double.tryParse(settings['prayer_custom_lng'] ?? '');
      if (customLat != null && customLng != null) {
        latitude = customLat;
        longitude = customLng;
      }
    } else {
      final cityResult = await db.query(
        'iran_cities',
        where: 'id = ?',
        whereArgs: [cityId],
        limit: 1,
      );

      if (cityResult.isNotEmpty) {
        latitude = (cityResult.first['latitude'] as num?)?.toDouble() ?? 35.6892;
        longitude = (cityResult.first['longitude'] as num?)?.toDouble() ?? 51.3890;
      }
    }

    // 2. Try online API first (if forced or not in SQLite cache)
    if (forceOnline) {
      final onlineTimes = await OnlinePrayerTimeService.instance
          .fetchPrayerTimesFromApi(
            latitude: latitude,
            longitude: longitude,
            date: date,
            calculationMethod: calcMethodStr,
          );
      if (onlineTimes != null) {
        return onlineTimes;
      }
    }

    // 3. Check SQLite cache with calculationMethod (C5)
    final cacheRows = await db.query(
      'prayer_times_cache',
      where: 'date = ? AND cityId = ? AND calculationMethod = ?',
      whereArgs: [dateStr, cityId, calcMethodStr],
      limit: 1,
    );

    if (cacheRows.isNotEmpty) {
      final row = cacheRows.first;
      return {
        'fajr': row['fajr'] as String,
        'sunrise': row['sunrise'] as String,
        'dhuhr': row['dhuhr'] as String,
        'asr': row['asr'] as String,
        'maghrib': row['maghrib'] as String,
        'isha': row['isha'] as String,
        'midnightShari': row['midnightShari'] as String,
        'sunset': row['sunset'] as String? ?? row['maghrib'] as String,
      };
    }

    // 4. Try online API fetch before local calculation
    final onlineTimes = await OnlinePrayerTimeService.instance
        .fetchPrayerTimesFromApi(
          latitude: latitude,
          longitude: longitude,
          date: date,
          calculationMethod: calcMethodStr,
        );

    if (onlineTimes != null) {
      return onlineTimes;
    }

    // 5. Offline Fallback: compute astronomical prayer times locally via package:adhan with ihtiyat (C5)
    return computePrayerTimesLocally(
      latitude: latitude,
      longitude: longitude,
      calcMethodStr: calcMethodStr,
      date: date,
      ihtiyatMinutes: ihtiyatMinutes,
    );
  }

  Map<String, String> computePrayerTimesLocally({
    required double latitude,
    required double longitude,
    required String calcMethodStr,
    required DateTime date,
    int ihtiyatMinutes = 0,
  }) {
    var method = CalculationMethod.tehran;
    if (calcMethodStr == 'MWL') {
      method = CalculationMethod.muslim_world_league;
    } else if (calcMethodStr == 'ISNA') {
      method = CalculationMethod.north_america;
    } else if (calcMethodStr == 'MAKKAH') {
      method = CalculationMethod.umm_al_qura;
    }

    final params = method.getParameters();

    final todayComponents = DateComponents(date.year, date.month, date.day);
    final todayTimes = PrayerTimes(
      Coordinates(latitude, longitude),
      todayComponents,
      params,
    );

    final tomorrow = date.add(const Duration(days: 1));
    final tomorrowComponents = DateComponents(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
    );
    final tomorrowTimes = PrayerTimes(
      Coordinates(latitude, longitude),
      tomorrowComponents,
      params,
    );

    final rawFajr = todayTimes.fajr;
    final sunrise = todayTimes.sunrise;
    final dhuhr = todayTimes.dhuhr;
    final asr = todayTimes.asr;
    final rawMaghrib = todayTimes.maghrib;
    final isha = todayTimes.isha;

    final rawTomorrowFajr = tomorrowTimes.fajr;

    // Apply ihtiyat minutes if configured (C5)
    final fajr = ihtiyatMinutes != 0 ? rawFajr.add(Duration(minutes: ihtiyatMinutes)) : rawFajr;
    final maghrib = ihtiyatMinutes != 0 ? rawMaghrib.add(Duration(minutes: ihtiyatMinutes)) : rawMaghrib;
    final tomorrowFajr = ihtiyatMinutes != 0 ? rawTomorrowFajr.add(Duration(minutes: ihtiyatMinutes)) : rawTomorrowFajr;

    final sunniParams = CalculationMethod.muslim_world_league.getParameters();
    final sunniTimes = PrayerTimes(
      Coordinates(latitude, longitude),
      todayComponents,
      sunniParams,
    );
    final sunset = sunniTimes.maghrib;

    // Midnight Shari is midpoint between Sunset and tomorrow's Fajr
    final midnightDuration = tomorrowFajr.difference(sunset);
    final midnightShari = sunset.add(midnightDuration ~/ 2);

    return {
      'fajr': _formatTime(fajr),
      'sunrise': _formatTime(sunrise),
      'dhuhr': _formatTime(dhuhr),
      'asr': _formatTime(asr),
      'maghrib': _formatTime(maghrib),
      'isha': _formatTime(isha),
      'midnightShari': _formatTime(midnightShari),
      'sunset': _formatTime(sunset),
    };
  }

  Future<void> cachePrayerTimes({
    required String cityId,
    required DateTime date,
    bool forceOnline = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);

    final times = await getPrayerTimesForDate(
      cityId: cityId,
      date: date,
      forceOnline: forceOnline,
    );

    final settingsResult = await db.query('app_settings');
    final settings = {
      for (final row in settingsResult)
        (row['key'] as String? ?? ''): (row['value'] as String? ?? ''),
    };
    final calcMethodStr =
        settings['prayer_calculation_method'] ?? 'TEHRAN_GEOPHYSICS';

    await db.insert('prayer_times_cache', {
      'date': dateStr,
      'cityId': cityId,
      'fajr': times['fajr'],
      'sunrise': times['sunrise'],
      'dhuhr': times['dhuhr'],
      'asr': times['asr'],
      'maghrib': times['maghrib'],
      'isha': times['isha'],
      'midnightShari': times['midnightShari'],
      'sunset': times['sunset'],
      'calculationMethod': calcMethodStr,
      'computedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }


  Future<int> cacheRange({
    required String cityId,
    required DateTime from,
    required int days,
    bool forceOnline = false,
    String? calculationMethod,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // 1. Fetch app_settings ONCE
    final settingsResult = await db.query('app_settings');
    final settings = {
      for (final row in settingsResult)
        (row['key'] as String? ?? ''): (row['value'] as String? ?? ''),
    };

    final calcMethodStr = calculationMethod ??
        settings['prayer_calculation_method'] ??
        'TEHRAN_GEOPHYSICS';
    final ihtiyatMinutes = int.tryParse(settings['ihtiyat_minutes'] ?? '0') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 2. Fetch coordinates
    var latitude = 35.6892;
    var longitude = 51.3890;

    if (cityId.startsWith('CUSTOM_') || settings['prayer_location_mode'] == 'CUSTOM_COORDS') {
      final customLat = double.tryParse(settings['prayer_custom_lat'] ?? '');
      final customLng = double.tryParse(settings['prayer_custom_lng'] ?? '');
      if (customLat != null && customLng != null) {
        latitude = customLat;
        longitude = customLng;
      }
    } else {
      final cityResult = await db.query(
        'iran_cities',
        where: 'id = ?',
        whereArgs: [cityId],
        limit: 1,
      );

      if (cityResult.isNotEmpty) {
        latitude = (cityResult.first['latitude'] as num?)?.toDouble() ?? 35.6892;
        longitude = (cityResult.first['longitude'] as num?)?.toDouble() ?? 51.3890;
      }
    }

    // 3. Batch insert using db.batch() for blazing fast atomic I/O
    final batch = db.batch();

    for (int i = 0; i < days; i++) {
      final date = DateTime(from.year, from.month, from.day + i);
      final dateStr = date.toIso8601String().substring(0, 10);
      final times = computePrayerTimesLocally(
        latitude: latitude,
        longitude: longitude,
        calcMethodStr: calcMethodStr,
        date: date,
        ihtiyatMinutes: ihtiyatMinutes,
      );

      batch.insert('prayer_times_cache', {
        'date': dateStr,
        'cityId': cityId,
        'fajr': times['fajr'],
        'sunrise': times['sunrise'],
        'dhuhr': times['dhuhr'],
        'asr': times['asr'],
        'maghrib': times['maghrib'],
        'isha': times['isha'],
        'midnightShari': times['midnightShari'],
        'sunset': times['sunset'],
        'calculationMethod': calcMethodStr,
        'computedAt': nowMs,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }


    await batch.commit(noResult: true);

    final thresholdDate = from
        .subtract(const Duration(days: 90))
        .toIso8601String()
        .substring(0, 10);
    try {
      await db.delete(
        'prayer_times_cache',
        where: 'date < ?',
        whereArgs: [thresholdDate],
      );
    } catch (_) {}

    return days;
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
