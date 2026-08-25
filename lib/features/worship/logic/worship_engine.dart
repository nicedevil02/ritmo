import 'dart:async';
import 'dart:convert';

import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/features/worship/logic/worship_repository.dart';
import 'package:ritmo/features/worship/logic/hijri_calendar.dart';
import 'package:ritmo/features/worship/logic/prayer_timeline.dart';
import 'package:ritmo/features/worship/logic/prayer_times.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/features/worship/logic/worship_occasions_data.dart';
import 'package:ritmo/features/worship/logic/fadhilat.dart' as fadhilat;
import 'package:ritmo/core/services/prayer_time_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/domain/completion/completion_gateway.dart';
import 'package:ritmo/core/domain/completion/completion_request.dart';
import 'package:ritmo/core/utils/cycle_consent_bridge.dart';

export 'package:ritmo/features/worship/logic/prayer_times.dart';

// ─── Engine-local models ─────────────────────────────────────────────────────

/// All data needed to render a single worship day, fetched in one batch.
class WorshipDay {
  const WorshipDay({
    required this.date,
    required this.hijri,
    required this.times,
    required this.practices,
    required this.seasons,
    required this.context,
    required this.occasions,
  });

  final DateTime date;
  final HijriDate hijri;
  final PrayerTimes times;
  final List<WorshipPracticeState> practices;
  final List<WorshipSeason> seasons;
  final WorshipDayContext context;
  final List<OccasionItem> occasions;
}

/// The state of a single worship practice on a specific day.
class WorshipPracticeState {
  const WorshipPracticeState({
    required this.practice,
    required this.dateStr,
    required this.countDone,
    required this.countTarget,
    this.resultType,
    this.quality,
    this.windowStart,
    this.windowEnd,
  });

  final WorshipPractice practice;

  /// Reference date for this state in YYYY-MM-DD format.
  final String dateStr;

  final int countDone;
  final int countTarget;

  /// DONE | SKIPPED | PARTIAL | QADA_ADDED | MISSED | null
  final String? resultType;

  /// EARLY | NORMAL | LATE | null
  final String? quality;

  /// Prayer window start (prayers only)
  final DateTime? windowStart;

  /// Prayer window end (prayers only)
  final DateTime? windowEnd;

  /// Only used for legacy rows prior to backfill of worship_completions table.
  /// Strictly date-scoped to avoid cross-date state leakage.
  int get _legacyDailyDone {
    if (resultType != null) return 0;
    if (practice.dailyDoneDate == null) return 0;
    if (practice.dailyDoneDate != dateStr) return 0;
    return practice.dailyDone;
  }

  bool get isQada => resultType == 'QADA_ADDED' || quality == 'QADA';

  bool get isDone =>
      !isQada &&
      (resultType == 'DONE' ||
          (resultType != null && countTarget > 0 && countDone >= countTarget) ||
          _legacyDailyDone >= 1);

  static const int _dailyDoneSkippedSentinel = -1;
  bool get isSkipped =>
      !isQada && (resultType == 'SKIPPED' || _legacyDailyDone == _dailyDoneSkippedSentinel);

  bool get isMissed => resultType == 'MISSED';
  bool get isPending => !isDone && !isSkipped && !isMissed && !isQada;
}

/// Result of a worship log operation — never throws for business paths.
sealed class WorshipLogResult {}

class WorshipLogOk extends WorshipLogResult {
  WorshipLogOk(this.undoToken);
  final String undoToken;
}

class WorshipLogBlocked extends WorshipLogResult {
  WorshipLogBlocked(this.reasonCode, this.userMessage);

  /// SUSPENDED_BY_CYCLE | QUOTA_EXHAUSTED | NOT_YET_DUE
  final String reasonCode;

  /// Friendly Persian message for display
  final String userMessage;
}

class WorshipLogFailed extends WorshipLogResult {
  WorshipLogFailed(this.error);
  final Object error;
}

/// Soft streak — ratio-based, not hard consecutive-days.
class SoftStreak {
  const SoftStreak({
    required this.daysDone,
    required this.windowDays,
    required this.currentRun,
  });

  final int daysDone;
  final int windowDays;
  final int currentRun;

  double get ratio => windowDays == 0 ? 0 : daysDone / windowDays;
}

/// Traveller / exemption context for a calendar day.
class WorshipDayContext {
  const WorshipDayContext({
    required this.date,
    this.isTraveller = false,
    this.fastingExempt = false,
    this.prayerExempt = false,
    this.exemptPrayers = const [],
    this.reason,
  });

  factory WorshipDayContext.fromMap(Map<String, dynamic> m) {
    return WorshipDayContext(
      date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
      isTraveller: (m['isTraveller'] as int? ?? 0) == 1,
      fastingExempt: (m['fastingExempt'] as int? ?? 0) == 1,
      prayerExempt: (m['prayerExempt'] as int? ?? 0) == 1,
      exemptPrayers: (m['exemptPrayers'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      reason: m['reason'] as String?,
    );
  }

  final DateTime date;
  final bool isTraveller;
  final bool fastingExempt;
  final bool prayerExempt;
  final List<String> exemptPrayers;

  /// TRAVEL | MENSTRUATION | ILLNESS | MANUAL
  final String? reason;

  String get _isoDate => date.toIso8601String().substring(0, 10);

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'date': _isoDate,
      'isTraveller': isTraveller ? 1 : 0,
      'fastingExempt': fastingExempt ? 1 : 0,
      'prayerExempt': prayerExempt ? 1 : 0,
      'exemptPrayers': exemptPrayers.join(','),
      'reason': reason,
      'createdAt': now,
      'updatedAt': now,
    };
  }
}

/// Debt augmented with estimated finish date and on-track ratio.
class WorshipDebtView {
  const WorshipDebtView({
    required this.debt,
    this.estimatedFinishDate,
    required this.onTrackRatio,
  });

  final WorshipDebt debt;
  final DateTime? estimatedFinishDate;
  final double onTrackRatio;
}

/// Occasion from the worship_occasions asset JSON.
class OccasionItem {
  const OccasionItem({
    required this.titleFa,
    required this.kind,
    required this.calendarType,
  });

  final String titleFa;

  /// NATIONAL | CELEBRATION | MOURNING | RELIGIOUS
  final String kind;

  /// 'solar' | 'hijri'
  final String calendarType;
}

// ─── WorshipEngine ──────────────────────────────────────────────────────────

/// Central engine for the Worship module (Prompt 048, Phase 1.4).
/// Every DB read/write in the worship module MUST go through here.
/// No widget may call [DatabaseHelper.instance.database] directly.
class WorshipEngine {
  WorshipEngine._();
  static final WorshipEngine instance = WorshipEngine._();

  /// تنها شرط معتبر برای «این عبادت باید دیده شود».
  /// هر خواننده‌ی جدید worship_practices موظف است از همین استفاده کند.
  static const String activePracticesWhere = 'isActive = 1 AND userDisabledAt IS NULL';
  static const String activePracticesOrderBy = 'sortOrder ASC, id ASC';

  // ── Cache ────────────────────────────────────────────────────────────────
  final Map<String, WorshipDay> _dayCache = {};
  Map<String, dynamic>? _settingsCache;
  int _hijriOffset = 0;

  /// Cached user-defined Hijri crescent offset (-2 to +2 days)
  int get hijriOffset => _hijriOffset;

  static bool _defaultsEnsured = false;

  Future<void> _ensureDefaultPractices(DatabaseExecutor db) async {
    if (_defaultsEnsured) return;
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      final practices = [
        {'id': 'wp_fajr', 'practiceType': 'PRAYER', 'subType': 'FAJR', 'title': 'نماز صبح', 'dailyTarget': 1, 'sortOrder': 1},
        {'id': 'wp_dhuhr', 'practiceType': 'PRAYER', 'subType': 'DHUHR', 'title': 'نماز ظهر و عصر', 'dailyTarget': 1, 'sortOrder': 2},
        {'id': 'wp_maghrib', 'practiceType': 'PRAYER', 'subType': 'MAGHRIB', 'title': 'نماز مغرب و عشا', 'dailyTarget': 1, 'sortOrder': 4},
        {'id': 'wp_asr', 'practiceType': 'PRAYER', 'subType': 'ASR', 'title': 'نماز عصر', 'dailyTarget': 1, 'sortOrder': 3},
        {'id': 'wp_isha', 'practiceType': 'PRAYER', 'subType': 'ISHA', 'title': 'نماز عشا', 'dailyTarget': 1, 'sortOrder': 5},
      ];

      for (final p in practices) {
        final existing = await db.query(
          'worship_practices',
          where: 'id = ?',
          whereArgs: [p['id']],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.insert(
            'worship_practices',
            {
              'id': p['id'],
              'practiceType': p['practiceType'],
              'subType': p['subType'],
              'title': p['title'],
              'dailyTarget': p['dailyTarget'],
              'dailyDone': 0,
              'sortOrder': p['sortOrder'],
              'isActive': (p['subType'] == 'ASR' || p['subType'] == 'ISHA') ? 0 : 1,
              'dailyDoneDate': todayStr,
              'createdAt': nowMs,
              'updatedAt': nowMs,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
      _defaultsEnsured = true;
    } catch (_) {}
  }

  // ── Settings ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _loadSettings(DatabaseExecutor db) async {
    if (_settingsCache != null) return _settingsCache!;
    const keys = [
      'prayer_city_id',
      'prayer_calculation_method',
      'show_asr_isha_prayers',
      'hijri_offset',
      'last_worship_sweep_date',
      'module_religion_enabled',
    ];
    final rows = await db.query(
      'app_settings',
      columns: ['key', 'value'],
      where: 'key IN (${List.filled(keys.length, '?').join(',')})',
      whereArgs: keys,
    );
    final map = <String, dynamic>{};
    for (final r in rows) {
      final k = r['key'] as String?;
      if (k != null) {
        map[k] = r['value'];
      }
    }
    if (map['prayer_city_id'] == null || (map['prayer_city_id'] as String).isEmpty) {
      map['prayer_city_id'] = 'TEHRAN_TEHRAN';
      try {
        await db.insert(
          'app_settings',
          {
            'key': 'prayer_city_id',
            'value': 'TEHRAN_TEHRAN',
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }
    _hijriOffset = int.tryParse(map['hijri_offset']?.toString() ?? '') ?? 0;

    // Sync Asr and Isha practices with show_asr_isha_prayers setting (Fixes H1)
    final showAsrIsha = map['show_asr_isha_prayers'] == 'true' ||
        map['show_asr_isha_prayers'] == '1' ||
        map['show_asr_isha_prayers'] == true;
    try {
      if (showAsrIsha) {
        await db.update('worship_practices', {'isActive': 1}, where: "id IN ('wp_asr', 'wp_isha')");
        await db.update('worship_practices', {'title': 'نماز ظهر'}, where: "id = 'wp_dhuhr'");
        await db.update('worship_practices', {'title': 'نماز مغرب'}, where: "id = 'wp_maghrib'");
      } else {
        await db.update('worship_practices', {'isActive': 0}, where: "id IN ('wp_asr', 'wp_isha')");
        await db.update('worship_practices', {'title': 'نماز ظهر و عصر'}, where: "id = 'wp_dhuhr'");
        await db.update('worship_practices', {'title': 'نماز مغرب و عشا'}, where: "id = 'wp_maghrib'");
      }
    } catch (_) {}

    _settingsCache = map;
    return map;
  }

  // ── Hijri (instant, offline — W-6) ───────────────────────────────────────

  /// Returns Hijri date for [date] — always instant, always offline (W-6).
  /// If [offsetDays] is not provided, defaults to user-configured [_hijriOffset].
  HijriDate hijriFor(DateTime date, {int? offsetDays}) =>
      HijriCalendarCalculator.hijriFromGregorian(
        date,
        offsetDays: offsetDays ?? _hijriOffset,
      );

  /// Ensures settings are loaded and returns the user's configured Hijri offset
  Future<int> getHijriOffset() async {
    if (_settingsCache != null) return _hijriOffset;
    final db = await DatabaseHelper.instance.database;
    await _loadSettings(db);
    return _hijriOffset;
  }

  /// Loads active scheduled mustahab practices for [date] (both daily and specific-day practices)
  Future<List<WorshipPractice>> loadActiveMustahabs(DateTime date) async {
    final db = await DatabaseHelper.instance.database;
    final weekdayIndex = date.weekday;
    final weekdayStr = weekdayIndex.toString();

    final results = await db.query(
      'worship_practices',
      where: "practiceType = 'MUSTAHAB' AND isActive = 1",
      orderBy: 'sortOrder ASC, createdAt DESC',
    );
    final allActive = results.map(WorshipPractice.fromMap).toList();

    return allActive.where((p) {
      final freq = (p.reminderFrequency).toUpperCase();
      if (freq.isEmpty || freq == 'DAILY') return true;
      if (freq == 'WEEKLY' || freq == 'SPECIFIC_DAYS') {
        final days = p.reminderDaysOfWeek;
        if (days == null || days.isEmpty) return true;
        if (days.contains(weekdayStr)) return true;
        if (weekdayIndex == DateTime.thursday && (days.contains('Thursday') || days.contains('4') || days.contains('پنجشنبه'))) return true;
        if (weekdayIndex == DateTime.friday && (days.contains('Friday') || days.contains('5') || days.contains('جمعه'))) return true;
        if (weekdayIndex == DateTime.saturday && (days.contains('Saturday') || days.contains('6') || days.contains('شنبه'))) return true;
        if (weekdayIndex == DateTime.sunday && (days.contains('Sunday') || days.contains('7') || days.contains('یکشنبه'))) return true;
        if (weekdayIndex == DateTime.monday && (days.contains('Monday') || days.contains('1') || days.contains('دوشنبه'))) return true;
        if (weekdayIndex == DateTime.tuesday && (days.contains('Tuesday') || days.contains('2') || days.contains('سه‌شنبه'))) return true;
        if (weekdayIndex == DateTime.wednesday && (days.contains('Wednesday') || days.contains('3') || days.contains('چهارشنبه'))) return true;
        return false;
      }
      return true;
    }).toList();
  }

  /// Alias for [loadActiveMustahabs] for backwards compatibility.
  Future<List<WorshipPractice>> loadSpecificDayMustahabs(DateTime date) async {
    return loadActiveMustahabs(date);
  }

  // ── Prayer times (W-5) ───────────────────────────────────────────────────

  /// Returns full-DateTime prayer times for [date].
  /// Reads from cache; self-heals if missing (W-12).
  Future<PrayerTimes> prayerTimes(DateTime date) async {
    final db = await DatabaseHelper.instance.database;
    return _prayerTimesFromDb(db, date);
  }

  static bool _cachePurged = false;

  Future<void> _purgeStalePrayerTimesCache(DatabaseExecutor db) async {
    if (_cachePurged) return;
    try {
      // Self-heal legacy default ihtiyat_minutes == '10' -> update to '0'
      final legacySetting = await db.query(
        'app_settings',
        where: "key = 'ihtiyat_minutes' AND value = '10'",
        limit: 1,
      );
      if (legacySetting.isNotEmpty) {
        await db.update(
          'app_settings',
          {'value': '0', 'updatedAt': DateTime.now().millisecondsSinceEpoch},
          where: "key = 'ihtiyat_minutes'",
        );
        await db.delete('prayer_times_cache');
      }
      _cachePurged = true;
    } catch (_) {}
  }

  Future<PrayerTimes> _prayerTimesFromDb(DatabaseExecutor db, DateTime date) async {
    await _purgeStalePrayerTimesCache(db);
    final dateStr = _ds(date);
    final settings = await _loadSettings(db);
    final cityId = settings['prayer_city_id'] as String? ?? '';
    final method = settings['prayer_calculation_method'] as String? ?? 'TEHRAN_GEOPHYSICS';
    final hijriOffset = int.tryParse(settings['hijri_offset']?.toString() ?? '') ?? 0;

    // Try ISO columns first (W-5), filter with calculationMethod (Fixes C5)
    final cacheRows = await db.query(
      'prayer_times_cache',
      where: 'date = ? AND cityId = ? AND calculationMethod = ?',
      whereArgs: [dateStr, cityId, method],
      limit: 1,
    );

    if (cacheRows.isNotEmpty) {
      final row = cacheRows.first;
      final fajr = _isoOrTime(row['fajrIso'] as String?, row['fajr'] as String?, date);
      final sunrise = _isoOrTime(row['sunriseIso'] as String?, row['sunrise'] as String?, date);
      final dhuhr = _isoOrTime(row['dhuhrIso'] as String?, row['dhuhr'] as String?, date);
      final asr = _isoOrTime(row['asrIso'] as String?, row['asr'] as String?, date);
      final maghrib = _isoOrTime(row['maghribIso'] as String?, row['maghrib'] as String?, date);
      final sunset = _isoOrTime(row['sunsetIso'] as String?, row['sunset'] as String?, date);
      final isha = _isoOrTime(row['ishaIso'] as String?, row['isha'] as String?, date);
      final midnight = _isoOrTime(row['midnightShariIso'] as String?, row['midnightShari'] as String?, date);
      final isFallbackLocation = (row['isFallbackLocation'] as int? ?? 0) == 1;

      // Ensure all prayer times are strictly present and valid without 00:00 midnight fallbacks (Fixes C6, H4)
      if (fajr != null && sunrise != null && dhuhr != null && asr != null &&
          maghrib != null && sunset != null && isha != null && midnight != null) {
        var midnightShari = midnight;
        if (midnightShari.isBefore(maghrib)) {
          midnightShari = midnightShari.add(const Duration(days: 1));
        }
        return PrayerTimes(
          date: dateStr,
          cityId: cityId,
          fajr: fajr,
          sunrise: sunrise,
          dhuhr: dhuhr,
          asr: asr,
          maghrib: maghrib,
          sunset: sunset,
          isha: isha,
          midnightShari: midnightShari,
          calculationMethod: method,
          isFallbackLocation: isFallbackLocation,
        );
      }
    }

    // Self-heal: compute and cache (W-12)
    return _computeAndCache(db, date, cityId, method, hijriOffset);
  }

  Future<PrayerTimes> _computeAndCache(
    DatabaseExecutor db,
    DateTime date,
    String cityId,
    String method,
    int hijriOffset,
  ) async {
    double lat = 35.6892, lon = 51.3890;
    var isFallback = cityId.isEmpty;

    if (cityId.isNotEmpty) {
      final coords = await _lookupCityLatLng(db, cityId);
      if (coords != null) {
        lat = coords['lat']!;
        lon = coords['lon']!;
      } else {
        isFallback = true;
        RitmoLogger.warning('WorshipEngine: city "$cityId" not found — using Tehran fallback (W-14)');
      }
    }

    final times = _calcTimes(date, lat, lon, method);
    final fallback = isFallback;

    final cacheData = {
      'date': _ds(date),
      'cityId': cityId,
      'calculationMethod': method,
      'isFallbackLocation': fallback ? 1 : 0,
      'fajr': times.fajrText,
      'sunrise': times.sunriseText,
      'dhuhr': times.dhuhrText,
      'asr': times.asrText,
      'maghrib': times.maghribText,
      'sunset': times.sunsetText,
      'isha': times.ishaText,
      'midnightShari': times.midnightShariText,
      'computedAt': DateTime.now().millisecondsSinceEpoch,
      'fajrIso': times.fajr.toIso8601String(),
      'sunriseIso': times.sunrise.toIso8601String(),
      'dhuhrIso': times.dhuhr.toIso8601String(),
      'asrIso': times.asr.toIso8601String(),
      'maghribIso': times.maghrib.toIso8601String(),
      'sunsetIso': times.sunset.toIso8601String(),
      'ishaIso': times.isha.toIso8601String(),
      'midnightShariIso': times.midnightShari.toIso8601String(),
    };

    await _insertPrayerTimesCache(db, cacheData);

    return PrayerTimes(
      date: _ds(date),
      cityId: cityId,
      fajr: times.fajr,
      sunrise: times.sunrise,
      dhuhr: times.dhuhr,
      asr: times.asr,
      maghrib: times.maghrib,
      sunset: times.sunset,
      isha: times.isha,
      midnightShari: times.midnightShari,
      calculationMethod: method,
      isFallbackLocation: fallback,
    );
  }

  Future<Map<String, double>?> _lookupCityLatLng(DatabaseExecutor db, String cityId) async {
    if (cityId.isEmpty) return null;
    try {
      if (cityId.startsWith('CUSTOM_')) {
        final customSettings = await db.query(
          'app_settings',
          where: "key IN ('prayer_custom_lat', 'prayer_custom_lng')",
        );
        double? lat, lon;
        for (final r in customSettings) {
          if (r['key'] == 'prayer_custom_lat') lat = double.tryParse(r['value']?.toString() ?? '');
          if (r['key'] == 'prayer_custom_lng') lon = double.tryParse(r['value']?.toString() ?? '');
        }
        if (lat != null && lon != null) {
          return {'lat': lat, 'lon': lon};
        }
      }
      final rows = await db.query(
        'iran_cities',
        where: 'id = ?',
        whereArgs: [cityId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        final latVal = row['latitude'] ?? row['lat'];
        final lonVal = row['longitude'] ?? row['lng'];
        if (latVal is num && lonVal is num) {
          return {'lat': latVal.toDouble(), 'lon': lonVal.toDouble()};
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _insertPrayerTimesCache(DatabaseExecutor db, Map<String, dynamic> row) async {
    try {
      await db.insert('prayer_times_cache', row, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {
      final fallbackRow = Map<String, dynamic>.from(row)
        ..remove('fajrIso')
        ..remove('sunriseIso')
        ..remove('dhuhrIso')
        ..remove('asrIso')
        ..remove('maghribIso')
        ..remove('sunsetIso')
        ..remove('ishaIso')
        ..remove('midnightShariIso');
      try {
        await db.insert('prayer_times_cache', fallbackRow, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    }
  }

  /// Builds yearly prayer cache in a single batch transaction (W-12).
  Future<void> cacheRange({int days = 365}) async {
    final db = await DatabaseHelper.instance.database;
    final settings = await _loadSettings(db);
    final cityId = settings['prayer_city_id'] as String? ?? '';
    final method = settings['prayer_calculation_method'] as String? ?? 'TEHRAN_GEOPHYSICS';

    double lat = 35.6892, lon = 51.3890;
    if (cityId.isNotEmpty) {
      final coords = await _lookupCityLatLng(db, cityId);
      if (coords != null) {
        lat = coords['lat']!;
        lon = coords['lon']!;
      }
    }

    final now = DateTime.now();
    final lLat = lat, lLon = lon; // capture for closure
    await db.transaction((txn) async {
      for (var i = 0; i < days; i++) {
        final d = now.add(Duration(days: i));
        final times = _calcTimes(d, lLat, lLon, method);
        await _insertPrayerTimesCache(txn, {
          'date': _ds(d),
          'cityId': cityId,
          'calculationMethod': method,
          'fajr': times.fajrText,
          'sunrise': times.sunriseText,
          'dhuhr': times.dhuhrText,
          'asr': times.asrText,
          'maghrib': times.maghribText,
          'sunset': times.sunsetText,
          'isha': times.ishaText,
          'midnightShari': times.midnightShariText,
          'computedAt': DateTime.now().millisecondsSinceEpoch,
          'fajrIso': times.fajr.toIso8601String(),
          'sunriseIso': times.sunrise.toIso8601String(),
          'dhuhrIso': times.dhuhr.toIso8601String(),
          'asrIso': times.asr.toIso8601String(),
          'maghribIso': times.maghrib.toIso8601String(),
          'sunsetIso': times.sunset.toIso8601String(),
          'ishaIso': times.isha.toIso8601String(),
          'midnightShariIso': times.midnightShari.toIso8601String(),
        });
      }
    });
  }

  // ── loadDay (max 3 queries per spec) ─────────────────────────────────────

  /// Loads all data needed for one worship day in at most 3 DB queries.
  Future<WorshipDay> loadDay(DateTime date) async {
    final cacheKey = _ds(date);
    if (_dayCache.containsKey(cacheKey)) return _dayCache[cacheKey]!;

    final db = await DatabaseHelper.instance.database;
    await _ensureDefaultPractices(db);
    final settings = await _loadSettings(db);
    final hijriOffset = int.tryParse(settings['hijri_offset']?.toString() ?? '') ?? 0;

    // ─ Query 1: practices (active, not user-disabled) ─
    List<Map<String, dynamic>> practiceRows;
    try {
      practiceRows = await db.query(
        'worship_practices',
        where: activePracticesWhere,
        orderBy: activePracticesOrderBy,
      );
    } catch (e, st) {
      RitmoLogger.warning('WorshipEngine.loadDay: fallback 1. error=$e', error: e, stack: st);
      try {
        practiceRows = await db.query(
          'worship_practices',
          where: 'isActive = 1',
          orderBy: activePracticesOrderBy,
        );
      } catch (e2, st2) {
        RitmoLogger.warning('WorshipEngine.loadDay: fallback 2. error=$e2', error: e2, stack: st2);
        practiceRows = await db.query(
          'worship_practices',
          orderBy: activePracticesOrderBy,
        );
      }
    }

    // ─ Query 2: completions for this date ─
    List<Map<String, dynamic>> completionRows = [];
    try {
      completionRows = await db.query(
        'worship_completions',
        where: 'dateStr = ?',
        whereArgs: [cacheKey],
      );
    } catch (_) {}

    // ─ Query 3: prayer times (self-healing) ─
    final times = await _prayerTimesFromDb(db, date);

    // Build completion lookup
    final completionMap = <String, Map<String, dynamic>>{};
    for (final row in completionRows) {
      completionMap[row['practiceId'] as String] = row;
    }

    // Build practice states
    final states = practiceRows.map((row) {
      final practice = WorshipPractice.fromMap(row);
      final comp = completionMap[practice.id];

      DateTime? winStart, winEnd;
      String? quality;
      if (practice.practiceType == 'PRAYER') {
        final slot = PrayerTimeline.getSlotFor(practice.subType ?? '', times);
        winStart = slot?.at;
        winEnd = slot != null ? PrayerTimeline.deadlineForSlot(slot.key, times) : null;
        if (comp != null) {
          quality = comp['quality'] as String?;
        }
      }

      return WorshipPracticeState(
        practice: practice,
        dateStr: cacheKey,
        countDone: comp != null ? (comp['countDone'] as int? ?? 0) : 0,
        countTarget: practice.dailyTarget,
        resultType: comp != null ? comp['resultType'] as String? : null,
        quality: quality,
        windowStart: winStart,
        windowEnd: winEnd,
      );
    }).toList();

    // Day context
    final ctx = await _loadDayContext(db, date);

    // Active seasons
    final hijri = hijriFor(date, offsetDays: hijriOffset);
    final seasons = await _loadActiveSeasons(db, date, hijri, times: times);

    // Occasions (W-16 asset)
    final occasions = await _loadOccasions(date, hijri);

    final day = WorshipDay(
      date: date,
      hijri: hijri,
      times: times,
      practices: states,
      seasons: seasons,
      context: ctx,
      occasions: occasions,
    );

    if (_dayCache.length >= 300) {
      _dayCache.remove(_dayCache.keys.first);
    }
    _dayCache[cacheKey] = day;
    return day;
  }

  /// Loads multiple consecutive days in batch (for weekly/monthly views).
  Future<List<WorshipDay>> loadRange(DateTime from, DateTime to) async {
    final result = <WorshipDay>[];
    var cur = from;
    while (!cur.isAfter(to)) {
      result.add(await loadDay(cur));
      cur = cur.add(const Duration(days: 1));
    }
    return result;
  }

  // ── logDone (F-2, F-4, E-5) ───────────────────────────────────────────────

  /// Logs completion of [practiceId] on [date].
  /// Increments count (tasbih/mustahab) or completes (prayer).
  /// For prayers: evaluates quality window based on [date] vs prayer times.
  Future<WorshipLogResult> logDone({
    required String practiceId,
    required DateTime date,
    int amount = 1,
    bool increment = false,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await _ensureDefaultPractices(db);
      final dateStr = _ds(date);
      final now = DateTime.now();
      final todayStr = _ds(now);
      final recordId = 'wc_${practiceId}_$dateStr';
      final nowMs = now.millisecondsSinceEpoch;

      final practice = await getPractice(practiceId);
      final dailyTarget = practice?.dailyTarget ?? 1;
      final practiceType = practice?.practiceType ?? 'PRAYER';

      // Time-gating & Quality window for prayers
      final isToday = dateStr == todayStr;

      if (practiceType == 'PRAYER' && practice != null) {
        final times = await _prayerTimesFromDb(db, date);
        final subType = practice.subType ?? '';
        final slot = PrayerTimeline.getSlotFor(subType, times);

        if (isToday && slot != null && now.isBefore(slot.at)) {
          final prayerTitle = slot.titleFa;
          return WorshipLogBlocked('NOT_YET_DUE', 'هنوز زمان $prayerTitle نرسیده است.');
        }

        final actualTime = isToday ? now : date;
        final quality = isToday ? _qualityWindow(subType, times, actualTime) : 'IN_TIME';
        
        final gatewayOutcome = await CompletionGateway.instance.submit(PrayerCompletion(
          prayerKey: practiceId,
          dateStr: dateStr,
          mode: quality,
        ));
        
        if (gatewayOutcome.isSuccess) {
           return WorshipLogOk(gatewayOutcome.undoToken ?? 'worship:$recordId');
        } else {
           return WorshipLogFailed(gatewayOutcome.errorMessage ?? '');
        }
      }

      // Incremental counting (E-5)
      var effectiveAmount = amount;
      if (increment) {
        final existingRows = await db.query(
          'worship_completions',
          where: 'practiceId = ? AND dateStr = ?',
          whereArgs: [practiceId, dateStr],
        );
        final currentCount = existingRows.isNotEmpty ? (existingRows.first['countDone'] as int? ?? 0) : 0;
        effectiveAmount = currentCount + amount;
      }
      
      final newCount = effectiveAmount.clamp(0, dailyTarget);
      final isDone = newCount >= dailyTarget;

      final completionRow = <String, dynamic>{
        'id': recordId,
        'practiceId': practiceId,
        'dateStr': dateStr,
        'practiceType': practiceType,
        'resultType': isDone ? 'DONE' : 'PARTIAL',
        'countDone': newCount,
        'countTarget': dailyTarget,
        'loggedAt': nowMs,
        'createdAt': nowMs,
      };

      await db.transaction((txn) async {
        await txn.insert(
          'worship_completions',
          completionRow,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (isToday) {
          // Write dailyDone as a write-only cache for today (never read in business logic)
          await txn.update(
            'worship_practices',
            {'dailyDone': newCount, 'dailyDoneDate': dateStr, 'updatedAt': nowMs},
            where: 'id = ?',
            whereArgs: [practiceId],
          );
        }
      });

      invalidate(date: date);
      DayAgendaService.instance.invalidateDate(dateStr);
      RitmoEventBus().fire(RitmoEvent(
        type: 'WorshipUpdated',
        timestamp: DateTime.now(),
        payload: {'date': dateStr, 'practiceId': practiceId},
      ));

      return WorshipLogOk('worship:$recordId');
    } catch (e) {
      RitmoLogger.error('WorshipEngine.logDone error: $e');
      return WorshipLogFailed(e);
    }
  }

  // ── logSkip (F-2) ─────────────────────────────────────────────────────────

  /// Logs that [practiceId] was skipped on [date].
  /// If [addToQada] is true, increments debt in `worship_debts`.
  Future<WorshipLogResult> logSkip({
    required String practiceId,
    required DateTime date,
    String? reason,
    bool addToQada = false,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final dateStr = _ds(date);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final recordId = 'wc_${practiceId}_$dateStr';

      final practice = await getPractice(practiceId);
      final practiceType = practice?.practiceType ?? 'PRAYER';

      await db.transaction((txn) async {
        await txn.insert(
          'worship_completions',
          {
            'id': recordId,
            'practiceId': practiceId,
            'dateStr': dateStr,
            'practiceType': practiceType,
            'resultType': addToQada ? 'QADA_ADDED' : 'SKIPPED',
            'countDone': 0,
            'reason': reason,
            'loggedAt': nowMs,
            'createdAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (addToQada) {
          final debtType = practiceType == 'FASTING'
              ? 'FASTING'
              : (practiceType == 'MUSTAHAB' ? 'MUSTAHAB' : 'PRAYER');
          final debtId = 'debt_${debtType}_$practiceId';

          final existingDebt = await txn.query('worship_debts', where: 'id = ?', whereArgs: [debtId]);
          if (existingDebt.isNotEmpty) {
            await txn.rawUpdate('''
              UPDATE worship_debts
              SET totalCount = totalCount + 1,
                  remainingCount = remainingCount + 1,
                  isArchived = 0,
                  updatedAt = ?
              WHERE id = ?
            ''', [nowMs, debtId]);
          } else {
            final practiceRows = await txn.query(
              'worship_practices',
              columns: ['title'],
              where: 'id = ?',
              whereArgs: [practiceId],
            );
            final title = practiceRows.isNotEmpty && practiceRows.first['title'] != null
                ? practiceRows.first['title'] as String
                : _defaultPracticeTitle(practiceId);

            await txn.insert('worship_debts', {
              'id': debtId,
              'debtType': debtType,
              'sourcePracticeId': practiceId,
              'title': title,
              'totalCount': 1,
              'remainingCount': 1,
              'dailyTarget': 1,
              'autoCreated': 1,
              'isArchived': 0,
              'createdAt': nowMs,
              'updatedAt': nowMs,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        if (dateStr == _ds(DateTime.now())) {
          await txn.update(
            'worship_practices',
            {'dailyDone': -1, 'dailyDoneDate': dateStr, 'updatedAt': nowMs},
            where: 'id = ?',
            whereArgs: [practiceId],
          );
        }
      });

      invalidate(date: date);
      DayAgendaService.instance.invalidateDate(dateStr);
      RitmoEventBus().fire(RitmoEvent(
        type: 'WorshipUpdated',
        timestamp: DateTime.now(),
        payload: {'date': dateStr, 'practiceId': practiceId},
      ));

      return WorshipLogOk('worship:$recordId');
    } catch (e) {
      RitmoLogger.error('WorshipEngine.logSkip error: $e');
      return WorshipLogFailed(e);
    }
  }

  /// Resolves the completion result type for a missed worship item.
  static String resolveMissResult({
    required WorshipPractice practice,
    required WorshipDayContext ctx,
    required bool suspended,
  }) {
    if (suspended) return 'SKIPPED';
    if (practice.allowQada) return 'QADA_ADDED';
    return 'MISSED';
  }

  /// Determines if a missed worship practice should increment the Qada debt counter.
  static bool shouldAddQada({
    required WorshipPractice practice,
    required WorshipDayContext ctx,
    required bool suspended,
  }) {
    if (suspended) return false;
    return practice.allowQada;
  }

  /// Fetches practice metadata by ID.
  Future<WorshipPractice?> getPractice(String practiceId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'worship_practices',
      where: 'id = ?',
      whereArgs: [practiceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WorshipPractice.fromMap(rows.first);
  }

  /// Clears a completion entry for a practice on a date.
  /// Safely decrements debt if a Qada debt was created.
  Future<WorshipLogResult> clearLog({
    required String practiceId,
    required DateTime date,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final dateStr = _ds(date);
      final todayStr = _ds(DateTime.now());
      final recordId = 'wc_${practiceId}_$dateStr';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await db.transaction((txn) async {
        final existing = await txn.query(
          'worship_completions',
          where: 'id = ?',
          whereArgs: [recordId],
          limit: 1,
        );

        final wasQada = existing.isNotEmpty && (existing.first['resultType'] == 'QADA_ADDED' || existing.first['resultType'] == 'QADA');
        final practiceType = existing.isNotEmpty
            ? (existing.first['practiceType'] as String? ?? 'PRAYER')
            : (practiceId.contains('fasting') ? 'FASTING' : 'PRAYER');
        final isSuspendedFasting = practiceType == 'FASTING' && existing.isNotEmpty && existing.first['resultType'] == 'SKIPPED';

        await txn.delete(
          'worship_completions',
          where: 'id = ?',
          whereArgs: [recordId],
        );

        if (dateStr == todayStr) {
          await txn.update(
            'worship_practices',
            {'dailyDone': 0, 'dailyDoneDate': dateStr, 'updatedAt': nowMs},
            where: 'id = ?',
            whereArgs: [practiceId],
          );
        }

        if (wasQada || isSuspendedFasting) {
          final debtType = practiceType == 'FASTING' ? 'FASTING' : (practiceType == 'MUSTAHAB' ? 'MUSTAHAB' : 'PRAYER');
          final debtId = 'debt_${debtType}_$practiceId';
          await txn.rawUpdate('''
            UPDATE worship_debts
            SET totalCount = MAX(0, totalCount - 1),
                remainingCount = MAX(0, remainingCount - 1),
                updatedAt = ?
            WHERE id = ?
          ''', [nowMs, debtId]);

          await txn.delete(
            'worship_debts',
            where: 'id = ? AND totalCount <= 0 AND remainingCount <= 0',
            whereArgs: [debtId],
          );

          // Synchronize worship_debt_routine archive state when debts reach 0
          final remainingDebts = await txn.query('worship_debts', where: 'isArchived = 0 AND remainingCount > 0', limit: 1);
          if (remainingDebts.isEmpty) {
            await txn.update('routines', {'isArchived': 1, 'updatedAt': nowMs}, where: "id = 'worship_debt_routine'");
            await txn.delete('simple_tasks', where: "linkedRoutineId = 'worship_debt_routine' OR title = 'بدهی عبادی'");
          }
        }
      });

      invalidate(date: date);
      DayAgendaService.instance.invalidateDate(dateStr);
      RitmoEventBus().fire(RitmoEvent(
        type: 'WorshipUpdated',
        timestamp: DateTime.now(),
        payload: {'date': dateStr, 'practiceId': practiceId},
      ));

      return WorshipLogOk('worship:$recordId');
    } catch (e) {
      RitmoLogger.error('WorshipEngine.clearLog error: $e');
      return WorshipLogFailed(e);
    }
  }

  /// Enables or disables a practice — persists across restarts (W-3).
  /// [userDisabledAt] ensures auto-seed never re-enables it.
  Future<void> setPracticeEnabled(String practiceId, bool enabled) async {
    final db = await DatabaseHelper.instance.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'worship_practices',
      {
        'isActive': enabled ? 1 : 0,
        'userDisabledAt': enabled ? null : DateTime.now().toIso8601String(),
        'updatedAt': nowMs,
      },
      where: 'id = ?',
      whereArgs: [practiceId],
    );
    invalidate();
    RitmoEventBus().fire(RitmoEvent(
      type: 'WorshipPracticeChanged',
      timestamp: DateTime.now(),
      payload: {'practiceId': practiceId, 'enabled': enabled},
    ));
  }

  /// Active worship debts alias for backwards compatibility
  Future<List<WorshipDebtView>> debts() => loadDebts();

  String _defaultPracticeTitle(String id) {
    final lower = id.toLowerCase();
    if (lower.contains('fajr')) return 'نماز صبح';
    if (lower.contains('dhuhr')) return 'نماز ظهر';
    if (lower.contains('asr')) return 'نماز عصر';
    if (lower.contains('maghrib')) return 'نماز مغرب';
    if (lower.contains('isha')) return 'نماز عشا';
    if (lower.contains('fasting')) return 'روزه قضا';
    if (lower.contains('tasbih')) return 'تسبیحات حضرت زهرا (س)';
    if (lower.contains('quran')) return 'قرائت قرآن';
    if (lower.contains('dhikr') || lower.contains('zikr')) return 'ذکر روزانه';
    if (lower.contains('mustahab')) return 'مستحبات';
    return 'عبادت قضاشده';
  }

  // ── Debts (F-3) ───────────────────────────────────────────────────────────

  /// Reads active debts with progress calculations and ETA estimates.
  Future<List<WorshipDebtView>> loadDebts() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'worship_debts',
      where: 'isArchived = 0 AND remainingCount > 0',
      orderBy: 'createdAt ASC',
    );
    return rows.map((row) {
      final debt = WorshipDebt.fromMap(row);
      DateTime? estimatedFinish;
      if (debt.dailyTarget > 0 && debt.remainingCount > 0) {
        final daysLeft = (debt.remainingCount / debt.dailyTarget).ceil();
        estimatedFinish = DateTime.now().add(Duration(days: daysLeft));
      }
      final done = debt.totalCount - debt.remainingCount;
      final onTrack = debt.totalCount > 0 ? done / debt.totalCount : 1.0;
      return WorshipDebtView(
        debt: debt,
        estimatedFinishDate: estimatedFinish,
        onTrackRatio: onTrack.clamp(0.0, 1.0),
      );
    }).toList();
  }

  // ── SoftStreak ────────────────────────────────────────────────────────────

  /// Ratio-based streak: counts DONE days in the past [window] days.
  Future<SoftStreak> softStreak(String practiceId, {int window = 30}) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final fromStr = _ds(now.subtract(Duration(days: window - 1)));
    final toStr = _ds(now);

    final rows = await db.query(
      'worship_completions',
      columns: ['dateStr', 'resultType'],
      where: 'practiceId = ? AND dateStr >= ? AND dateStr <= ?',
      whereArgs: [practiceId, fromStr, toStr],
      orderBy: 'dateStr DESC',
    );

    var daysDone = 0;
    var currentRun = 0;
    var inRun = true;

    for (final row in rows) {
      final rt = row['resultType'] as String?;
      if (rt == 'DONE') {
        daysDone++;
        if (inRun) currentRun++;
      } else {
        inRun = false;
      }
    }

    return SoftStreak(daysDone: daysDone, windowDays: window, currentRun: currentRun);
  }

  // ── dayContext (F-1) ──────────────────────────────────────────────────────

  /// Loads traveller/exemption context for [date].
  Future<WorshipDayContext> dayContext(DateTime date) async {
    return _loadDayContext(await DatabaseHelper.instance.database, date);
  }

  Future<WorshipDayContext> _loadDayContext(DatabaseExecutor db, DateTime date) async {
    final suspended = await CycleConsentBridge.isWorshipSuspended(targetDate: date);
    final calculatedExemptPrayers = <String>[];
    bool isFullDayExempt = suspended;

    if (suspended) {
      final period = await CycleConsentBridge.getActivePeriod(targetDate: date);
      if (period != null) {
        final startStr = period['startDate'] as String?;
        final endStr = period['endDate'] as String?;
        
        DateTime? startTime;
        DateTime? endTime;
        
        if (startStr != null && startStr.contains('T')) {
          startTime = DateTime.tryParse(startStr);
        }
        if (endStr != null && endStr.contains('T')) {
          endTime = DateTime.tryParse(endStr);
        }
        
        if (startTime != null || endTime != null) {
          final times = await _prayerTimesFromDb(db, date);
          isFullDayExempt = false;
          
          final prayersToCheck = [
            {'key': 'FAJR', 'start': times.fajr, 'end': times.sunrise},
            {'key': 'DHUHR', 'start': times.dhuhr, 'end': times.sunset},
            {'key': 'ASR', 'start': times.asr, 'end': times.sunset},
            {'key': 'MAGHRIB', 'start': times.maghrib, 'end': times.midnightShari},
            {'key': 'ISHA', 'start': times.isha, 'end': times.midnightShari},
          ];
          
          for (final p in prayersToCheck) {
            final pStart = p['start'] as DateTime;
            final pEnd = p['end'] as DateTime;
            
            bool exempt = true;
            if (startTime != null && pStart.isBefore(startTime)) {
              exempt = false; // Adhan was before period started, so it's obligatory
            }
            if (endTime != null && pEnd.isAfter(endTime)) {
              exempt = false; // Deadline is after period ended, so it's obligatory
            }
            
            if (exempt) {
              calculatedExemptPrayers.add(p['key'] as String);
            }
          }
          
          if (calculatedExemptPrayers.length == 5) {
            isFullDayExempt = true;
          }
        }
      }
    }

    try {
      final rows = await db.query(
        'worship_day_context',
        where: 'date = ?',
        whereArgs: [_ds(date)],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final ctx = WorshipDayContext.fromMap(rows.first);
        if (suspended) {
          return WorshipDayContext(
            date: date,
            isTraveller: ctx.isTraveller,
            prayerExempt: isFullDayExempt || ctx.prayerExempt,
            exemptPrayers: isFullDayExempt ? [] : (calculatedExemptPrayers.isNotEmpty ? calculatedExemptPrayers : ctx.exemptPrayers),
            fastingExempt: true,
            reason: 'MENSTRUATION',
          );
        }
        return ctx;
      }
    } catch (_) {}

    if (suspended) {
      return WorshipDayContext(
        date: date,
        prayerExempt: isFullDayExempt,
        exemptPrayers: isFullDayExempt ? [] : calculatedExemptPrayers,
        fastingExempt: true,
        reason: 'MENSTRUATION',
      );
    }

    return WorshipDayContext(date: date);
  }

  /// Persists traveller/exemption context for a day.
  Future<void> setDayContext(WorshipDayContext ctx) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'worship_day_context',
        ctx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      invalidate(date: ctx.date);
    } catch (e, st) {
      RitmoLog.error('WorshipEngine', 'Error setting day context: $e', e, st);
    }
  }

  // ── activeSeasons ─────────────────────────────────────────────────────────

  /// Returns worship seasons active on [date] (W-7 recurrence logic).
  Future<List<WorshipSeason>> activeSeasons(DateTime date) async {
    final db = await DatabaseHelper.instance.database;
    final hijriOffset = int.tryParse(
          (_settingsCache ?? {})['hijri_offset']?.toString() ?? '',
        ) ??
        0;
    final times = await _prayerTimesFromDb(db, date);
    return _loadActiveSeasons(db, date, hijriFor(date, offsetDays: hijriOffset), times: times);
  }

  Future<List<WorshipSeason>> _loadActiveSeasons(
    DatabaseExecutor db,
    DateTime date,
    HijriDate hijri, {
    PrayerTimes? times,
  }) async {
    try {
      final rows = await db.query('worship_seasons', where: 'isActive = 1');
      return rows
          .map((r) => WorshipSeason.fromMap(r))
          .where((s) => _isSeasonActive(s, date, hijri, times: times))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Recurrence-aware season check (W-7). No fragile string parsing.
  bool _isSeasonActive(WorshipSeason s, DateTime date, HijriDate hijri, {PrayerTimes? times}) {
    if (!s.isActive) return false;
    final rec = s.recurrence ?? s.calendar.toUpperCase();

    switch (rec) {
      case 'RANGE_HIJRI':
        return _hijriInRange(hijri, s.startDate, s.endDate);

      case 'RANGE_SOLAR':
        try {
          final j = Jalali.fromDateTime(date);
          final sp = s.startDate.split('-');
          final ep = s.endDate.split('-');
          final sm = int.parse(sp[sp.length - 2]), sd = int.parse(sp.last);
          final em = int.parse(ep[ep.length - 2]), ed = int.parse(ep.last);
          final jm = j.month, jd = j.day;
          return (jm > sm || (jm == sm && jd >= sd)) && (jm < em || (jm == em && jd <= ed));
        } catch (_) {
          return false;
        }

      case 'DAYS_OF_EVERY_HIJRI_MONTH':
        return _parseDayList(s.dayList).contains(hijri.day);

      case 'DAYS_OF_HIJRI_MONTH':
        final dayList = _parseDayList(s.dayList);
        return (s.hijriMonth == null || s.hijriMonth == hijri.month) &&
            dayList.contains(hijri.day);

      case 'NIGHTS_OF_HIJRI_MONTH':
        // After maghrib → the night belongs to the NEXT Hijri day (Fixes H5)
        final isAfterMaghrib = times != null
            ? (date.isAfter(times.maghrib) || date.isAtSameMomentAs(times.maghrib))
            : (date.hour >= 19);
        final effectiveDate = isAfterMaghrib ? date.add(const Duration(days: 1)) : date;
        final effectiveHijri = hijriFor(effectiveDate);
        final dayList = _parseDayList(s.dayList);
        return (s.hijriMonth == null || s.hijriMonth == effectiveHijri.month) &&
            dayList.contains(effectiveHijri.day);

      default:
        return _hijriInRange(hijri, s.startDate, s.endDate);
    }
  }

  bool _hijriInRange(HijriDate h, String startDate, String endDate) {
    try {
      final sp = startDate.split('-');
      final ep = endDate.split('-');
      final sm = int.parse(sp[sp.length - 2]), sd = int.parse(sp.last);
      final em = int.parse(ep[ep.length - 2]), ed = int.parse(ep.last);
      final cm = h.month, cd = h.day;

      final afterStart = cm > sm || (cm == sm && cd >= sd);
      final beforeEnd = cm < em || (cm == em && cd <= ed);
      if (em > sm || (em == sm && ed >= sd)) return afterStart && beforeEnd;
      return afterStart || beforeEnd; // wraps Hijri new year
    } catch (_) {
      return false;
    }
  }

  List<int> _parseDayList(String? json) {
    if (json == null) return [];
    try {
      return (jsonDecode(json) as List<dynamic>).cast<int>();
    } catch (_) {
      return [];
    }
  }

  // ── Occasions (W-16) ─────────────────────────────────────────────────────

  Future<List<OccasionItem>> _loadOccasions(DateTime date, HijriDate hijri) async {
    final j = Jalali.fromDateTime(date);
    final occasions = WorshipOccasionsData.getOccasionsForDay(j, hijri);
    return occasions.map((occ) {
      String kind = 'RELIGIOUS';
      switch (occ.category) {
        case WorshipOccasionCategory.celebration:
          kind = 'CELEBRATION';
          break;
        case WorshipOccasionCategory.mourning:
          kind = 'MOURNING';
          break;
        case WorshipOccasionCategory.national:
          kind = 'NATIONAL';
          break;
        case WorshipOccasionCategory.worshipDeed:
        case WorshipOccasionCategory.fasting:
          kind = 'RELIGIOUS';
          break;
      }
      return OccasionItem(
        titleFa: occ.title,
        kind: kind,
        calendarType: 'hijri',
      );
    }).toList();
  }

  // ── invalidate ────────────────────────────────────────────────────────────

  /// Invalidates cached data. Must be called after every write.
  void invalidate({DateTime? date}) {
    WorshipRepository.instance.invalidateCache();
    if (date != null) {
      _dayCache.remove(_ds(date));
    } else {
      _dayCache.clear();
    }
    _settingsCache = null;
    _hijriOffset = 0;
  }

  // ── Prayer time computation (offline trig — W-5) ─────────────────────────

  PrayerTimes _calcTimes(DateTime date, double lat, double lon, String method) {
    final map = PrayerTimeProvider.instance.computePrayerTimesLocally(
      latitude: lat,
      longitude: lon,
      calcMethodStr: method,
      date: date,
    );

    final maghrib = _isoOrTime(null, map['maghrib'], date) ?? date;
    final sunset = _isoOrTime(null, map['sunset'], date) ?? date;
    final isha = _isoOrTime(null, map['isha'], date) ?? date;
    var midnightShari = _isoOrTime(null, map['midnightShari'], date) ?? date;
    if (midnightShari.isBefore(maghrib)) {
      midnightShari = midnightShari.add(const Duration(days: 1));
    }

    return PrayerTimes(
      date: _ds(date),
      cityId: '',
      fajr: _isoOrTime(null, map['fajr'], date) ?? date,
      sunrise: _isoOrTime(null, map['sunrise'], date) ?? date,
      dhuhr: _isoOrTime(null, map['dhuhr'], date) ?? date,
      asr: _isoOrTime(null, map['asr'], date) ?? date,
      maghrib: maghrib,
      sunset: sunset,
      isha: isha,
      midnightShari: midnightShari,
      calculationMethod: method,
    );
  }

  // ── Trig helpers ──────────────────────────────────────────────────────────



  DateTime? _isoOrTime(String? iso, String? hhMm, DateTime base) {
    if (iso != null && iso.isNotEmpty) return DateTime.tryParse(iso);
    if (hhMm != null && hhMm.isNotEmpty) {
      final p = hhMm.split(':');
      if (p.length >= 2) {
        final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
        if (h != null && m != null) return DateTime(base.year, base.month, base.day, h, m);
      }
    }
    return null;
  }

  String _qualityWindow(String subType, PrayerTimes times, DateTime at) {
    final slot = PrayerTimeline.getSlotFor(subType, times);
    if (slot == null) return 'IN_TIME';
    final deadline = PrayerTimeline.deadlineForSlot(slot.key, times);
    if (deadline == null) return 'IN_TIME';

    return fadhilat.qualityAt(at, slot.at, deadline).code;
  }

  static String _ds(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
