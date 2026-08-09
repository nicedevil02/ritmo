import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/worship/logic/worship_completion_repository.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';

class WorshipAgendaSource {
  final List<Map<String, dynamic>> prayerPractices;
  final List<Map<String, dynamic>> mustahabPractices;
  final List<Map<String, dynamic>> worshipDebts;
  final Map<String, String> settingsMap;
  final bool religionEnabled;
  final Map<String, HijriDate> cachedHijriDates;
  final Database db;

  WorshipAgendaSource({
    required this.prayerPractices,
    required this.mustahabPractices,
    required this.worshipDebts,
    required this.settingsMap,
    required this.religionEnabled,
    required this.cachedHijriDates,
    required this.db,
  });

  static Future<WorshipAgendaSource> load(Database db, Map<String, String> settingsMap) async {
    final religionEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_religion_enabled');
    if (!religionEnabled) {
      return WorshipAgendaSource(
        prayerPractices: const [],
        mustahabPractices: const [],
        worshipDebts: const [],
        settingsMap: settingsMap,
        religionEnabled: false,
        cachedHijriDates: {},
        db: db,
      );
    }
    final prayerPractices = await db.query('worship_practices', where: 'practiceType = ?', whereArgs: ['OBLIGATORY_PRAYER']);
    final mustahabPractices = await db.query('worship_practices', where: 'practiceType != ?', whereArgs: ['OBLIGATORY_PRAYER']);
    final worshipDebts = await db.query('worship_debts');

    return WorshipAgendaSource(
      prayerPractices: prayerPractices,
      mustahabPractices: mustahabPractices,
      worshipDebts: worshipDebts,
      settingsMap: settingsMap,
      religionEnabled: true,
      cachedHijriDates: {},
      db: db,
    );
  }

  Future<List<AgendaItem>> itemsForDate(DateTime date, String dateStr, Map<String, String> prayerTimes, bool wantsPrayer, bool wantsMustahab, bool wantsWorshipDebt) async {
    if (!religionEnabled) return const [];
    
    final items = <AgendaItem>[];
    final worshipStatuses = await WorshipCompletionRepository.instance.statusForDate(dateStr);
    
    if (wantsPrayer) {
      items.addAll(_collectPrayers(dateStr, dateStr == _dateStr(DateTime.now()), prayerTimes, worshipStatuses));
    }
    
    if (wantsMustahab) {
      HijriDate? hijriDate;
      if (mustahabPractices.any((p) => p['reminderFrequency'] == 'LUNAR_MONTHLY')) {
        hijriDate = await _getHijriDate(date);
      }
      items.addAll(await _collectMustahab(dateStr, dateStr == _dateStr(DateTime.now()), prayerTimes, hijriDate, worshipStatuses));
    }
    
    if (wantsWorshipDebt) {
      items.addAll(_collectWorshipDebts(dateStr));
    }
    
    return items;
  }
  
  static String _dateStr(DateTime dt) => dt.toIso8601String().substring(0, 10);
  
  static DateTime? _parseDateTime(String dateStr, String? timeOfDay, {bool nextDayIfBefore = false, DateTime? referenceTime}) {
    if (timeOfDay == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(timeOfDay.trim());
    if (match == null) return null;
    
    final h = int.tryParse(match.group(1)!) ?? 0;
    final m = int.tryParse(match.group(2)!) ?? 0;
    var dt = DateTime.parse(dateStr);
    dt = DateTime(dt.year, dt.month, dt.day, h, m);
    
    if (nextDayIfBefore && referenceTime != null && dt.isBefore(referenceTime)) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
  }

  static const Map<String, String> _prayerSubTypeToKey = {
    'FAJR': 'fajr',
    'DHUHR': 'dhuhr',
    'ASR': 'asr',
    'MAGHRIB': 'maghrib',
    'ISHA': 'isha',
  };

  List<AgendaItem> _collectPrayers(
    
    String dateStr,
    bool isToday,
    Map<String, String> prayerTimes,
    Map<String, WorshipDayStatus> statuses,
  ) {
    final items = <AgendaItem>[];
    
    // Group by subType for combining Dhuhr/Asr and Maghrib/Isha
    final bySubType = <String, Map<String, dynamic>>{};
    final others = <Map<String, dynamic>>[];
    
    for (final p in prayerPractices) {
      final subType = (p['subType'] as String? ?? '').toUpperCase();
      if (['FAJR', 'DHUHR', 'ASR', 'MAGHRIB', 'ISHA'].contains(subType)) {
        bySubType[subType] = p;
      } else {
        others.add(p);
      }
    }

    final showSeparate = settingsMap['show_asr_isha_prayers'] == 'true';

    // 1. Fajr
    final fajr = bySubType['FAJR'];
    if (fajr != null) {
      final id = fajr['id'] as String;
      final timeOfDay = prayerTimes['fajr'];
      final status = statuses[id];
      final completion = status?.isDone == true ? AgendaCompletion.done : AgendaCompletion.pending;

      final start = _parseDateTime(dateStr, prayerTimes['fajr']);
      final end = _parseDateTime(dateStr, prayerTimes['sunrise']);
      items.add(AgendaItem(
        id: 'prayer:$id',
        domain: AgendaDomain.prayer,
        sourceId: id,
        title: fajr['title'] as String? ?? 'نماز صبح',
        dateStr: dateStr,
        timeOfDay: timeOfDay,
        durationMinutes: 10,
        category: Category.religious,
        completion: completion,
        priority: 3,
        isEssential: true,
        deepLink: AgendaDeepLink(domain: AgendaDomain.prayer, targetId: id),
        windowStart: start,
        windowEnd: end,
        meta: {'practice': fajr},
      ));
    }

    // 2. Dhuhr & Asr
    final dhuhr = bySubType['DHUHR'];
    final asr = bySubType['ASR'];

    if (showSeparate) {
      if (dhuhr != null) {
        final id = dhuhr['id'] as String;
        final timeOfDay = prayerTimes['dhuhr'];
        final status = statuses[id];
        final completion = status?.isDone == true ? AgendaCompletion.done : AgendaCompletion.pending;
        final start = _parseDateTime(dateStr, prayerTimes['dhuhr']);
        final end = _parseDateTime(dateStr, prayerTimes['asr']);
        items.add(AgendaItem(
          id: 'prayer:$id:dhuhr',
          domain: AgendaDomain.prayer,
          sourceId: id,
          title: dhuhr['title'] as String? ?? 'نماز ظهر',
          dateStr: dateStr,
          timeOfDay: timeOfDay,
          durationMinutes: 15,
          category: Category.religious,
          completion: completion,
          priority: 3,
          isEssential: true,
          deepLink: AgendaDeepLink(domain: AgendaDomain.prayer, targetId: id),
          windowStart: start,
          windowEnd: end,
          meta: {'practice': dhuhr},
        ));
      }
      if (asr != null) {
        final id = asr['id'] as String;
        final timeOfDay = prayerTimes['asr'];
        final status = statuses[id];
        final completion = status?.isDone == true ? AgendaCompletion.done : AgendaCompletion.pending;
        final start = _parseDateTime(dateStr, prayerTimes['asr']);
        final end = _parseDateTime(dateStr, prayerTimes['maghrib']);
        items.add(AgendaItem(
          id: 'prayer:$id:asr',
          domain: AgendaDomain.prayer,
          sourceId: id,
          title: asr['title'] as String? ?? 'نماز عصر',
          dateStr: dateStr,
          timeOfDay: timeOfDay,
          durationMinutes: 15,
          category: Category.religious,
          completion: completion,
          priority: 3,
          isEssential: true,
          deepLink: AgendaDeepLink(domain: AgendaDomain.prayer, targetId: id),
          windowStart: start,
          windowEnd: end,
          meta: {'practice': asr},
        ));
      }
    } else {
      if (dhuhr != null || asr != null) {
        final representative = dhuhr ?? asr!;
        final id = representative['id'] as String;
        final timeOfDay = prayerTimes['dhuhr'] ?? prayerTimes['asr'];
        
        final dhuhrDone = dhuhr == null || statuses[dhuhr['id'] as String]?.isDone == true;
        final asrDone = asr == null || statuses[asr['id'] as String]?.isDone == true;
        final completion = (dhuhrDone && asrDone) ? AgendaCompletion.done : AgendaCompletion.pending;
        
        final start = _parseDateTime(dateStr, prayerTimes['dhuhr']);
        final end = _parseDateTime(dateStr, prayerTimes['maghrib']);
        items.add(AgendaItem(
          id: 'prayer:${id}:dhuhr_asr',
          domain: AgendaDomain.prayer,
          sourceId: id,
          title: 'نماز ظهر و عصر',
          dateStr: dateStr,
          timeOfDay: timeOfDay,
          durationMinutes: 20,
          category: Category.religious,
          completion: completion,
          priority: 3,
          isEssential: true,
          deepLink: AgendaDeepLink(domain: AgendaDomain.prayer, targetId: id),
          windowStart: start,
          windowEnd: end,
          meta: {'practice': representative},
        ));
      }
    }

    // 3. Maghrib & Isha
    final maghrib = bySubType['MAGHRIB'];
    final isha = bySubType['ISHA'];

    if (showSeparate) {
      if (maghrib != null) {
        final id = maghrib['id'] as String;
        final timeOfDay = prayerTimes['maghrib'];
        final status = statuses[id];
        final completion = status?.isDone == true ? AgendaCompletion.done : AgendaCompletion.pending;
        final start = _parseDateTime(dateStr, prayerTimes['maghrib']);
        final end = _parseDateTime(dateStr, prayerTimes['isha']);
        items.add(AgendaItem(
          id: 'prayer:$id:maghrib',
          domain: AgendaDomain.prayer,
          sourceId: id,
          title: maghrib['title'] as String? ?? 'نماز مغرب',
          dateStr: dateStr,
          timeOfDay: timeOfDay,
          durationMinutes: 15,
          category: Category.religious,
          completion: completion,
          priority: 3,
          isEssential: true,
          deepLink: AgendaDeepLink(domain: AgendaDomain.prayer, targetId: id),
          windowStart: start,
          windowEnd: end,
          meta: {'practice': maghrib},
        ));
      }
      if (isha != null) {
        final id = isha['id'] as String;
        final timeOfDay = prayerTimes['isha'];
        final status = statuses[id];
        final completion = status?.isDone == true ? AgendaCompletion.done : AgendaCompletion.pending;
        final start = _parseDateTime(dateStr, prayerTimes['isha']);
        final end = _parseDateTime(dateStr, prayerTimes['midnightShari'], nextDayIfBefore: true, referenceTime: start);
        items.add(AgendaItem(
          id: 'prayer:$id:isha',
          domain: AgendaDomain.prayer,
          sourceId: id,
          title: isha['title'] as String? ?? 'نماز عشا',
          dateStr: dateStr,
          timeOfDay: timeOfDay,
          durationMinutes: 15,
          category: Category.religious,
          completion: completion,
          priority: 3,
          isEssential: true,
          deepLink: AgendaDeepLink(domain: AgendaDomain.prayer, targetId: id),
          windowStart: start,
          windowEnd: end,
          meta: {'practice': isha},
        ));
      }
    } else {
      if (maghrib != null || isha != null) {
        final representative = maghrib ?? isha!;
        final id = representative['id'] as String;
        final timeOfDay = prayerTimes['maghrib'] ?? prayerTimes['isha'];
        
        final maghribDone = maghrib == null || statuses[maghrib['id'] as String]?.isDone == true;
        final ishaDone = isha == null || statuses[isha['id'] as String]?.isDone == true;
        final completion = (maghribDone && ishaDone) ? AgendaCompletion.done : AgendaCompletion.pending;
        
        final start = _parseDateTime(dateStr, prayerTimes['maghrib']);
        final end = _parseDateTime(dateStr, prayerTimes['midnightShari'], nextDayIfBefore: true, referenceTime: start);
        items.add(AgendaItem(
          id: 'prayer:${id}:maghrib_isha',
          domain: AgendaDomain.prayer,
          sourceId: id,
          title: 'نماز مغرب و عشا',
          dateStr: dateStr,
          timeOfDay: timeOfDay,
          durationMinutes: 20,
          category: Category.religious,
          completion: completion,
          priority: 3,
          isEssential: true,
          deepLink: AgendaDeepLink(domain: AgendaDomain.prayer, targetId: id),
          windowStart: start,
          windowEnd: end,
          meta: {'practice': representative},
        ));
      }
    }

    // 4. Others
    for (final p in others) {
      final id = p['id'] as String;
      final subType = (p['subType'] as String? ?? '').toUpperCase();
      final timeKey = _prayerSubTypeToKey[subType];
      final timeOfDay = timeKey != null ? prayerTimes[timeKey] : null;

      final status = statuses[id];
      final completion = status?.isDone == true ? AgendaCompletion.done : AgendaCompletion.pending;

      items.add(AgendaItem(
        id: 'prayer:$id',
        domain: AgendaDomain.prayer,
        sourceId: id,
        title: p['title'] as String? ?? '',
        dateStr: dateStr,
        timeOfDay: timeOfDay,
        durationMinutes: 10,
        category: Category.religious,
        completion: completion,
        priority: 3,
        isEssential: true,
        deepLink: AgendaDeepLink(domain: AgendaDomain.prayer, targetId: id),
        meta: {'practice': p},
      ));
    }

    return items;
  }

  String? _resolveAnchorTime(
    String anchor,
    int offsetMinutes,
    Map<String, String> prayerTimes,
    Map<String, String> settingsMap,
  ) {
    String? baseTime;
    if (anchor == 'WAKEUP') {
      baseTime = settingsMap['sleep_target_wake'] ?? '07:00';
    } else if (anchor == 'BEDTIME') {
      baseTime = settingsMap['sleep_target_bedtime'] ?? '23:30';
    } else {
      String key;
      switch (anchor.toUpperCase()) {
        case 'FAJR':
          key = 'fajr';
        case 'SUNRISE':
          key = 'sunrise';
        case 'DHUHR':
          key = 'dhuhr';
        case 'ASR':
          key = 'asr';
        case 'MAGHRIB':
          key = 'maghrib';
        case 'ISHA':
          key = 'isha';
        case 'MIDNIGHT_SHARI':
          key = 'midnightShari';
        default:
          return null;
      }
      baseTime = prayerTimes[key];
    }

    if (baseTime == null || baseTime.isEmpty) return null;

    final parts = baseTime.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      var total = h * 60 + m + offsetMinutes;
      if (total < 0) total += 24 * 60;
      final rh = (total ~/ 60) % 24;
      final rm = total % 60;
      return '${rh.toString().padLeft(2, '0')}:${rm.toString().padLeft(2, '0')}';
    }
    return null;
  }

  Future<HijriDate?> _getHijriDate(DateTime date, ) async {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final key = 'hijri_date_${y}_${m}_$d';
    if (cachedHijriDates.containsKey(key)) {
      return cachedHijriDates[key];
    }
    // Fallback: fetch from database/network (original call)
    final hDate = await HijriDate.getOrFetch(date, db);
    if (hDate != null) {
      cachedHijriDates[key] = hDate;
    }
    return hDate;
  }

  Future<bool> _isLastDayOfHijriMonth(DateTime date, ) async {
    final tomorrow = date.add(const Duration(days: 1));
    final tomorrowHijri = await _getHijriDate(tomorrow);
    return tomorrowHijri != null && tomorrowHijri.day == 1;
  }

  Future<List<AgendaItem>> _collectMustahab(
    
    String dateStr,
    bool isToday,
    Map<String, String> prayerTimes,
    HijriDate? hijriDate,
    Map<String, WorshipDayStatus> statuses,
  ) async {
    final items = <AgendaItem>[];
    for (final p in mustahabPractices) {
      final id = p['id'] as String;

      // Filter by days of week or month if applicable
      final freq = p['reminderFrequency'] as String? ?? 'DAILY';
      if (freq == 'WEEKLY') {
        final daysOfWeekStr = p['reminderDaysOfWeek'] as String?;
        if (daysOfWeekStr != null && daysOfWeekStr.trim().isNotEmpty) {
          final parsedDate = DateTime.parse(dateStr);
          final allowedDays = daysOfWeekStr.split(',').map(int.tryParse).whereType<int>().toSet();
          if (allowedDays.isNotEmpty && !allowedDays.contains(parsedDate.weekday)) {
            continue; // Skip this mustahab for this date
          }
        }
      } else if (freq == 'MONTHLY') {
        final dayOfMonthStr = p['reminderDaysOfWeek'] as String?;
        if (dayOfMonthStr != null && dayOfMonthStr.trim().isNotEmpty) {
          final parsedDate = DateTime.parse(dateStr);
          final jalaliDate = Jalali.fromDateTime(parsedDate);
          final allowedDays = dayOfMonthStr.split(',').map(int.tryParse).whereType<int>().toSet();
          if (allowedDays.isNotEmpty) {
            var matches = false;
            for (final targetDay in allowedDays) {
              if (jalaliDate.day == targetDay) {
                matches = true;
                break;
              }
              // Handle day 31 / 30 for months with fewer days
              if (targetDay == 31 && jalaliDate.monthLength < 31 && jalaliDate.day == jalaliDate.monthLength) {
                matches = true;
                break;
              }
              if (targetDay == 30 && jalaliDate.monthLength < 30 && jalaliDate.day == jalaliDate.monthLength) {
                matches = true;
                break;
              }
            }
            if (!matches) {
              continue; // Skip this mustahab for this date
            }
          }
        }
      } else if (freq == 'LUNAR_MONTHLY') {
        final dayOfMonthStr = p['reminderDaysOfWeek'] as String?;
        if (dayOfMonthStr != null && dayOfMonthStr.trim().isNotEmpty && hijriDate != null) {
          final allowedDays = dayOfMonthStr.split(',').map(int.tryParse).whereType<int>().toSet();
          if (allowedDays.isNotEmpty) {
            var matches = false;
            final parsedDate = DateTime.parse(dateStr);
            final isLastDay = await _isLastDayOfHijriMonth(parsedDate);
            for (final targetDay in allowedDays) {
              if (hijriDate.day == targetDay) {
                matches = true;
                break;
              }
              // Handle day 30 for 29-day Hijri months
              if (targetDay == 30 && isLastDay && hijriDate.day == 29) {
                matches = true;
                break;
              }
            }
            if (!matches) {
              continue; // Skip this mustahab for this date
            }
          }
        }
      } else if (freq == 'ONCE') {
        final targetDateStr = p['reminderDaysOfWeek'] as String?;
        if (targetDateStr != dateStr) {
          continue; // Skip this mustahab for this date
        }
      }

      final status = statuses[id];
      final completion = status?.isDone == true ? AgendaCompletion.done : AgendaCompletion.pending;

      final anchor = p['reminderAnchor'] as String? ?? 'NONE';
      final offsetMinutes = p['reminderOffsetMinutes'] as int? ?? 0;
      var resolvedTimes = <String>[];

      if (anchor != 'NONE') {
        final resolved = _resolveAnchorTime(anchor, offsetMinutes, prayerTimes, settingsMap);
        if (resolved != null) {
          resolvedTimes.add(resolved);
        }
      } else {
        // Multiple fixed times
        final multipleTimesStr = p['reminderTimes'] as String?;
        if (multipleTimesStr != null && multipleTimesStr.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(multipleTimesStr);
            if (decoded is List) {
              resolvedTimes = decoded.map((e) => e.toString()).toList();
            }
          } catch (_) {}
        }
        if (resolvedTimes.isEmpty) {
          final singleTime = p['reminderTime'] as String?;
          if (singleTime != null && singleTime.isNotEmpty) {
            resolvedTimes.add(singleTime);
          }
        }
      }

      if (resolvedTimes.isEmpty) {
        resolvedTimes.add('08:00'); // fallback
      }

      for (final resolvedTime in resolvedTimes) {
        items.add(AgendaItem(
          id: resolvedTimes.length > 1 ? 'mustahab:$id:$resolvedTime' : 'mustahab:$id',
          domain: AgendaDomain.mustahab,
          sourceId: id,
          title: p['title'] as String? ?? '',
          dateStr: dateStr,
          timeOfDay: resolvedTime,
          durationMinutes: 15,
          category: Category.religious,
          completion: completion,
          deepLink: AgendaDeepLink(domain: AgendaDomain.mustahab, targetId: id),
          meta: {'practice': p},
        ));
      }
    }
    return items;
  }

  List<AgendaItem> _collectWorshipDebts( String dateStr) {
    final items = <AgendaItem>[];
    for (final dbt in worshipDebts) {
      final id = dbt['id'] as String;
      final remaining = dbt['remainingCount'] as int? ?? 0;
      if (remaining <= 0) continue;
      items.add(AgendaItem(
        id: 'worshipDebt:$id',
        domain: AgendaDomain.worshipDebt,
        sourceId: id,
        title: dbt['title'] as String? ?? 'قضا',
        subtitle: '$remaining باقی‌مانده',
        dateStr: dateStr,
        category: Category.religious,
        priority: 0.5,
        deepLink:
            AgendaDeepLink(domain: AgendaDomain.worshipDebt, targetId: id),
        meta: {'debt': dbt},
      ));
    }
    return items;
  }


}
