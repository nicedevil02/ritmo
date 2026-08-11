import 'dart:convert';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/worship/logic/worship_completion_repository.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/models/worship_models.dart' hide toPersianDigits;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';

class WorshipAgendaSource implements AgendaSource {
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
    required this.statusesByDate,
    required this.contextsByDate,
    required this.db,
  });

  final Map<String, Map<String, WorshipDayStatus>> statusesByDate;
  final Map<String, WorshipDayContext> contextsByDate;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.prayer, AgendaDomain.mustahab, AgendaDomain.worshipDebt};

  @override
  bool get isEnabled => religionEnabled;

  static Future<WorshipAgendaSource> load(
    Database db,
    Map<String, String> settingsMap,
    DateTime start,
    DateTime end,
  ) async {
    final religionEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_religion_enabled');
    if (!religionEnabled) {
      return WorshipAgendaSource(
        prayerPractices: const [],
        mustahabPractices: const [],
        worshipDebts: const [],
        settingsMap: settingsMap,
        religionEnabled: false,
        cachedHijriDates: {},
        statusesByDate: {},
        contextsByDate: {},
        db: db,
      );
    }
    final prayerPractices = await db.query(
      'worship_practices',
      where: 'practiceType = ? AND isActive = 1 AND userDisabledAt IS NULL',
      whereArgs: ['PRAYER'],
      orderBy: 'id ASC',
    );
    final mustahabPractices = await db.query(
      'worship_practices',
      where: 'practiceType != ? AND isActive = 1 AND userDisabledAt IS NULL',
      whereArgs: ['PRAYER'],
      orderBy: 'id ASC',
    );
    // Worship debts are no longer shown in the calendar per user request
    final worshipDebts = const <Map<String, dynamic>>[];

    final startStr = _dateStr(start);
    final endStr = _dateStr(end);
    
    // Fetch all statuses at once (E-14 N+1 fix)
    final statusesByDate = await WorshipCompletionRepository.instance.statusForRange(startStr, endStr);
    
    final contextsByDate = <String, WorshipDayContext>{};
    final cachedHijriDates = <String, HijriDate>{};

    var current = start;
    // add an extra day for checking the last day of month in mustahab
    final fetchEnd = end.add(const Duration(days: 1)); 
    while (!current.isAfter(fetchEnd)) {
      final dateStr = _dateStr(current);
      // Prefetch contexts (and maybe other things)
      if (!current.isAfter(end)) {
         contextsByDate[dateStr] = await WorshipEngine.instance.dayContext(current);
      }
      
      // Prefetch hijri dates
      final y = current.year;
      final m = current.month.toString().padLeft(2, '0');
      final d = current.day.toString().padLeft(2, '0');
      final key = 'hijri_date_${y}_${m}_$d';
      final hDate = await HijriDate.getOrFetch(current, db);
      if (hDate != null) {
        cachedHijriDates[key] = hDate;
      }
      
      current = current.add(const Duration(days: 1));
    }

    return WorshipAgendaSource(
      prayerPractices: prayerPractices,
      mustahabPractices: mustahabPractices,
      worshipDebts: worshipDebts,
      settingsMap: settingsMap,
      religionEnabled: true,
      cachedHijriDates: cachedHijriDates,
      statusesByDate: statusesByDate,
      contextsByDate: contextsByDate,
      db: db,
    );
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!religionEnabled) return const [];
    
    final items = <AgendaItem>[];
    final worshipStatuses = statusesByDate[ctx.dateStr] ?? {};
    
    if (ctx.options.wants(AgendaDomain.prayer)) {
      items.addAll(_collectPrayers(ctx.dateStr, ctx.isToday, ctx.prayerTimes, worshipStatuses, contextsByDate[ctx.dateStr]));
    }
    
    if (ctx.options.wants(AgendaDomain.mustahab)) {
      HijriDate? hijriDate;
      if (mustahabPractices.any((p) => p['reminderFrequency'] == 'LUNAR_MONTHLY')) {
        hijriDate = _getHijriDateSync(ctx.date);
      }
      items.addAll(_collectMustahab(ctx.dateStr, ctx.isToday, ctx.prayerTimes, hijriDate, worshipStatuses));
    }
    
    if (ctx.options.wants(AgendaDomain.worshipDebt)) {
      items.addAll(_collectWorshipDebts(ctx.dateStr));
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
    WorshipDayContext? context,
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

    final showSeparate = false; // Always group prayers in the calendar

    // Exemption check helpers
    bool isExempt(String groupKey) {
      if (context == null) return false;
      if (context.prayerExempt) return true;
      return context.exemptPrayers.contains(groupKey);
    }

    // 1. Fajr
    final fajr = bySubType['FAJR'];
    if (fajr != null && !isExempt('FAJR')) {
      final id = fajr['id'] as String;
      final timeOfDay = prayerTimes['fajr'];
      final status = statuses[id];
      final completion = status?.isDone == true ? AgendaCompletion.done : AgendaCompletion.pending;

      final start = _parseDateTime(dateStr, prayerTimes['fajr']);
      final end = _parseDateTime(dateStr, prayerTimes['sunrise']);
      items.add(AgendaItem(
        id: 'prayer:$id:$dateStr',
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
          id: buildAgendaItemId(AgendaDomain.prayer, '$id:dhuhr', dateStr),
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
          id: buildAgendaItemId(AgendaDomain.prayer, '$id:asr', dateStr),
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
        if (isExempt('DHUHR_ASR')) {
          // completely exempt
        } else {
          final representative = dhuhr ?? asr!;
          final id = representative['id'] as String;
          final timeOfDay = prayerTimes['dhuhr'] ?? prayerTimes['asr'];
          
          final dhuhrDone = dhuhr == null || statuses[dhuhr['id'] as String]?.isDone == true;
          final asrDone = asr == null || statuses[asr['id'] as String]?.isDone == true;
          final completion = (dhuhrDone && asrDone) ? AgendaCompletion.done : AgendaCompletion.pending;
          
          final start = _parseDateTime(dateStr, prayerTimes['dhuhr']);
        final end = _parseDateTime(dateStr, prayerTimes['maghrib']);
        items.add(AgendaItem(
          id: buildAgendaItemId(AgendaDomain.prayer, '${id}:dhuhr_asr', dateStr),
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
          id: buildAgendaItemId(AgendaDomain.prayer, '$id:maghrib', dateStr),
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
          id: buildAgendaItemId(AgendaDomain.prayer, '$id:isha', dateStr),
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
        if (isExempt('MAGHRIB_ISHA')) {
          // completely exempt
        } else {
          final representative = maghrib ?? isha!;
          final id = representative['id'] as String;
          final timeOfDay = prayerTimes['maghrib'] ?? prayerTimes['isha'];
          
          final maghribDone = maghrib == null || statuses[maghrib['id'] as String]?.isDone == true;
          final ishaDone = isha == null || statuses[isha['id'] as String]?.isDone == true;
          final completion = (maghribDone && ishaDone) ? AgendaCompletion.done : AgendaCompletion.pending;
          
          final start = _parseDateTime(dateStr, prayerTimes['maghrib']);
        final end = _parseDateTime(dateStr, prayerTimes['midnightShari'], nextDayIfBefore: true, referenceTime: start);
        items.add(AgendaItem(
          id: buildAgendaItemId(AgendaDomain.prayer, '${id}:maghrib_isha', dateStr),
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
    }

    // 4. Other Prayers
    for (final p in others) {
      final id = p['id'] as String;
      final subType = (p['subType'] as String? ?? '').toUpperCase();
      final timeKey = _prayerSubTypeToKey[subType];
      final timeOfDay = timeKey != null ? prayerTimes[timeKey] : null;

      final status = statuses[id];
      final completion = status?.isDone == true ? AgendaCompletion.done : AgendaCompletion.pending;

      items.add(AgendaItem(
        id: 'prayer:$id:$dateStr',
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
      total = total.clamp(0, 24 * 60 - 1);
      final rh = total ~/ 60;
      final rm = total % 60;
      return '${rh.toString().padLeft(2, '0')}:${rm.toString().padLeft(2, '0')}';
    }
    return null;
  }

  HijriDate? _getHijriDateSync(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final key = 'hijri_date_${y}_${m}_$d';
    return cachedHijriDates[key];
  }

  bool _isLastDayOfHijriMonthSync(DateTime date) {
    final tomorrow = date.add(const Duration(days: 1));
    final tomorrowHijri = _getHijriDateSync(tomorrow);
    return tomorrowHijri != null && tomorrowHijri.day == 1;
  }

  List<AgendaItem> _collectMustahab(
    
    String dateStr,
    bool isToday,
    Map<String, String> prayerTimes,
    HijriDate? hijriDate,
    Map<String, WorshipDayStatus> statuses,
  ) {
    final items = <AgendaItem>[];
    
    // E-14: Cache parsed dates for the loop
    final parsedDate = DateTime.parse(dateStr);
    final jalaliDate = Jalali.fromDateTime(parsedDate);
    final isLastDayHijri = _isLastDayOfHijriMonthSync(parsedDate);

    for (final p in mustahabPractices) {
      final id = p['id'] as String;
      
      try {
        // Filter by days of week or month if applicable
        final freq = p['reminderFrequency'] as String? ?? 'DAILY';
        if (freq == 'WEEKLY') {
          // E-9: The daysOfWeekStr uses DateTime.weekday directly (1=Monday, ..., 7=Sunday).
          // The database currently stores values conforming to this mapping.
          final daysOfWeekStr = p['reminderDaysOfWeek'] as String?;
          if (daysOfWeekStr != null && daysOfWeekStr.trim().isNotEmpty) {
            final allowedDays = daysOfWeekStr.split(',').map(int.tryParse).whereType<int>().toSet();
            if (allowedDays.isNotEmpty) {
              if (!allowedDays.contains(parsedDate.weekday)) {
                continue; // Skip this mustahab for this date
              }
            } else {
              continue; // E-10: do not fail-open
            }
          } else {
            RitmoLogger.error('Missing reminderDaysOfWeek for WEEKLY practice $id');
            continue;
          }
        } else if (freq == 'MONTHLY') {
          final dayOfMonthStr = p['reminderDaysOfWeek'] as String?;
          if (dayOfMonthStr != null && dayOfMonthStr.trim().isNotEmpty) {
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
            } else {
              continue; // E-10: do not fail-open
            }
          } else {
            RitmoLogger.error('Missing reminderDaysOfWeek for MONTHLY practice $id');
            continue;
          }
        } else if (freq == 'LUNAR_MONTHLY') {
          final dayOfMonthStr = p['reminderDaysOfWeek'] as String?;
          if (dayOfMonthStr != null && dayOfMonthStr.trim().isNotEmpty) {
            if (hijriDate != null) {
              final allowedDays = dayOfMonthStr.split(',').map(int.tryParse).whereType<int>().toSet();
              if (allowedDays.isNotEmpty) {
                var matches = false;
                for (final targetDay in allowedDays) {
                  if (hijriDate.day == targetDay) {
                    matches = true;
                    break;
                  }
                  // Handle day 30 for 29-day Hijri months
                  if (targetDay == 30 && isLastDayHijri && hijriDate.day == 29) {
                    matches = true;
                    break;
                  }
                }
                if (!matches) {
                  continue; // Skip this mustahab for this date
                }
              } else {
                continue; // E-10: do not fail-open
              }
            } else {
              // Hijri date could not be calculated, but it's required for LUNAR_MONTHLY
              RitmoLogger.error('HijriDate is null for LUNAR_MONTHLY practice $id on date $dateStr');
              continue;
            }
          } else {
            RitmoLogger.error('Missing reminderDaysOfWeek for LUNAR_MONTHLY practice $id');
            continue;
          }
        } else if (freq == 'ONCE') {
          final targetDateStr = p['reminderDaysOfWeek'] as String?;
          if (targetDateStr != null && targetDateStr.trim().isNotEmpty) {
            if (targetDateStr != dateStr) {
              continue; // Skip this mustahab for this date
            }
          } else {
            RitmoLogger.error('Missing reminderDaysOfWeek (target date) for ONCE practice $id');
            continue;
          }
        }

        final status = statuses[id];
        final completion = status?.isDone == true ? AgendaCompletion.done : AgendaCompletion.pending;

        final anchor = p['reminderAnchor'] as String? ?? 'NONE';
        final offsetMinutes = p['reminderOffsetMinutes'] as int? ?? 0;
        var resolvedTimes = <String?>[];

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
            } catch (e, st) { 
              RitmoLogger.error('Error decoding reminderTimes for $id: $e\n$st'); 
            }
          }
          if (resolvedTimes.isEmpty) {
            final singleTime = p['reminderTime'] as String?;
            if (singleTime != null && singleTime.isNotEmpty) {
              resolvedTimes.add(singleTime);
            }
          }
        }

        if (resolvedTimes.isEmpty) {
          resolvedTimes.add(null); // fallback (no fixed time)
        }

        final dailyTarget = p['dailyTarget'] as int? ?? 1;
        final countDone = status?.countDone ?? 0;
        final freqFa = freq == 'WEEKLY' ? 'هفتگی'
            : freq == 'MONTHLY' ? 'ماهانه'
            : freq == 'LUNAR_MONTHLY' ? 'ماهانه'
            : freq == 'ONCE' ? 'یک‌بار'
            : 'روزانه';

        final targetStr = dailyTarget > 1 ? '${toPersianDigits(countDone.toString())} از ${toPersianDigits(dailyTarget.toString())}' : '';
        var subtitle = targetStr.isNotEmpty ? '$targetStr • $freqFa' : freqFa;
        
        if (resolvedTimes.length > 1) {
          subtitle += ' • ${toPersianDigits(resolvedTimes.length.toString())} وعده';
        }

        final firstTime = resolvedTimes.first;

        items.add(AgendaItem(
          id: buildAgendaItemId(AgendaDomain.mustahab, id, dateStr),
          domain: AgendaDomain.mustahab,
          sourceId: id,
          title: p['title'] as String? ?? '',
          subtitle: subtitle,
          dateStr: dateStr,
          timeOfDay: firstTime,
          durationMinutes: 15,
          category: Category.religious,
          priority: (p['sortOrder'] as num? ?? 0).toDouble(),
          completion: completion,
          deepLink: AgendaDeepLink(domain: AgendaDomain.mustahab, targetId: id),
          meta: {'practice': p},
        ));
      } catch (e, st) {
        RitmoLogger.error('Error processing mustahab practice $id in _collectMustahab: $e\n$st');
        continue;
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
        id: buildAgendaItemId(AgendaDomain.worshipDebt, id, dateStr),
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
