import 'package:flutter/material.dart';

class QuickAddResult {
  QuickAddResult({
    required this.title,
    required this.itemType,
    this.timeOfDay,
    required this.recurrenceType,
    this.intervalDays,
    this.intervalHours,
    this.weekdays,
    this.daysOffset,
    this.targetDurationMinutes,
  });
  final String title;
  final String itemType;
  final TimeOfDay? timeOfDay;
  final String recurrenceType;
  final int? intervalDays;
  final int? intervalHours;
  final Set<int>? weekdays;
  final int? daysOffset;
  final int? targetDurationMinutes;
}

class QuickAddParser {
  static String _normalizeDigits(String text) {
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    var result = text;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(persianDigits[i], englishDigits[i]);
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return result;
  }

  static int _adjustHour(int hour, String? modifier) {
    if (modifier == null) return hour;
    modifier = modifier.trim();
    if (modifier == 'صبح' || modifier == 'بامداد') {
      return hour == 12 ? 0 : hour;
    } else if (modifier == 'ظهر') {
      return hour == 12 ? 12 : hour + 12; // Usually 1-3 PM is after noon
    } else if (modifier == 'عصر' || modifier == 'بعد از ظهر' || modifier == 'بعدازظهر') {
      return hour < 12 ? hour + 12 : hour;
    } else if (modifier == 'شب') {
      if (hour >= 1 && hour <= 4) return hour; // Bamdad
      if (hour >= 5 && hour < 12) return hour + 12;
      if (hour == 12) return 0; // Midnight
    }
    return hour;
  }

  static QuickAddResult parse(String rawText) {
    // 1. Normalize
    final text = _normalizeDigits(rawText);
    
    var itemType = 'ROUTINE';
    TimeOfDay? timeOfDay;
    var recurrenceType = 'EVERY_DAY';
    int? intervalDays;
    int? intervalHours;
    Set<int>? weekdays;
    int? daysOffset;
    int? targetDurationMinutes;

    final spansToRemove = <({int start, int end})>[];

    // Helper to add span securely
    void addSpan(Match m) {
      spansToRemove.add((start: m.start, end: m.end));
    }

    // 2. Parse Duration
    final durationRegexes = [
      RegExp(r'(?:یک|1)\s*ساعت\s*و\s*نیم'),
      RegExp(r'(?:یک|1)\s*ساعت'),
      RegExp(r'نیم\s*ساعت'),
      RegExp(r'یه\s*ربع'),
      RegExp(r'(?<!هر\s*)(\d+)\s*ساعت\s*و\s*نیم'),
      RegExp(r'(?<!هر\s*)(\d+)\s*ساعت'),
      RegExp(r'(\d+)\s*دقیقه')
    ];

    for (int i = 0; i < durationRegexes.length; i++) {
      final m = durationRegexes[i].firstMatch(text);
      if (m != null) {
        if (i == 0) targetDurationMinutes = 90;
        else if (i == 1) targetDurationMinutes = 60;
        else if (i == 2) targetDurationMinutes = 30;
        else if (i == 3) targetDurationMinutes = 15;
        else if (i == 4) targetDurationMinutes = int.parse(m.group(1)!) * 60 + 30;
        else if (i == 5) targetDurationMinutes = int.parse(m.group(1)!) * 60;
        else if (i == 6) targetDurationMinutes = int.parse(m.group(1)!);
        
        addSpan(m);
        break; // Only parse one duration
      }
    }

    final dateKeywords = {
      'پس فردا': 2, 'پس‌فردا': 2,
      'فردا': 1,
      'امروز': 0, 'امشب': 0
    };
    
    for (final e in dateKeywords.entries) {
      final m = RegExp('(?<![\\p{L}\\p{N}])${e.key}(?![\\p{L}\\p{N}])', unicode: true).firstMatch(text);
      if (m != null) {
        daysOffset = e.value;
        addSpan(m);
        break;
      }
    }

    final taskKeywords = ['فردا', 'امروز', 'امشب', 'یکبار', 'تسک', 'کار', 'وظیفه'];
    final reminderKeywords = ['یادآور', 'اعلان', 'هشدار', 'زنگ'];

    if (taskKeywords.any((k) => RegExp('(?<![\\p{L}\\p{N}])$k(?![\\p{L}\\p{N}])', unicode: true).hasMatch(text))) {
      itemType = 'TASK';
    } else if (reminderKeywords.any((k) => RegExp('(?<![\\p{L}\\p{N}])$k(?![\\p{L}\\p{N}])', unicode: true).hasMatch(text))) {
      itemType = 'REMINDER';
    }

    // 4. Parse Time (anchored!)
    const modRegexStr = r'(?:صبح|بامداد|ظهر|عصر|شب|بعد\s*از\s*ظهر|بعدازظهر)';
    
    // Check Format 1: HH:MM or HH٪MM
    final timeColonRegex = RegExp(r'(?:ساعت\s+)?(\d{1,2})\s*[:٪]\s*(\d{2})');
    final mColon = timeColonRegex.firstMatch(text);
    
    if (mColon != null) {
      final h = int.parse(mColon.group(1)!);
      final m = int.parse(mColon.group(2)!);
      
      final modRegexAfter = RegExp('^\\s*$modRegexStr');
      final modRegexBefore = RegExp('$modRegexStr\\s*(?:ساعت\\s*)?\$');
      
      final modMatchAfter = modRegexAfter.firstMatch(text.substring(mColon.end));
      final modMatchBefore = modRegexBefore.firstMatch(text.substring(0, mColon.start));
      
      String? modifier;
      var start = mColon.start;
      var end = mColon.end;
      
      if (modMatchAfter != null) {
        modifier = modMatchAfter.group(1);
        end += modMatchAfter.end;
      } else if (modMatchBefore != null) {
        modifier = modMatchBefore.group(1);
        start = modMatchBefore.start;
      }
      
      timeOfDay = TimeOfDay(hour: _adjustHour(h, modifier), minute: m);
      spansToRemove.add((start: start, end: end));
    } else {
      // Check Format 2: Text time (e.g. ساعت 5, 5 عصر, عصر 5)
      // Matches an optional modifier, optional ساعت, the hour, optional نیم, and optional modifier
      final timeTextRegex = RegExp('(?:($modRegexStr)\\s+)?(?:ساعت\\s+)?(\\d{1,2})(?:\\s*(?:و\\s*)?نیم)?(?:\\s+($modRegexStr))?');
      final mText = timeTextRegex.firstMatch(text);
      if (mText != null) {
        // BUT we need to make sure we don't just match a random digit as time if it doesn't have 'ساعت' or a modifier!
        final modBefore = mText.group(1);
        final hourStr = mText.group(2)!;
        final modAfter = mText.group(3);
        final hasSaaat = text.substring(mText.start, mText.end).contains('ساعت');
        final hasNim = text.substring(mText.start, mText.end).contains('نیم');
        
        if (modBefore != null || modAfter != null || hasSaaat || hasNim) {
          final h = int.parse(hourStr);
          final m = hasNim ? 30 : 0;
          timeOfDay = TimeOfDay(hour: _adjustHour(h, modBefore ?? modAfter), minute: m);
          addSpan(mText);
        }
      }
    }

    // 5. Parse Recurrence
    if (text.contains('هر روز') || text.contains('روزانه')) {
      recurrenceType = 'EVERY_DAY';
      for (final m in RegExp(r'(?<![\p{L}\p{N}])(?:هر روز|روزانه)(?![\p{L}\p{N}])', unicode: true).allMatches(text)) addSpan(m);
    } else if (text.contains('روزهای کاری') || text.contains('شنبه تا چهارشنبه')) {
      recurrenceType = 'WORKDAYS';
      for (final m in RegExp(r'(?<![\p{L}\p{N}])(?:روزهای کاری|شنبه تا چهارشنبه)(?![\p{L}\p{N}])', unicode: true).allMatches(text)) addSpan(m);
    } else if (text.contains('آخر هفته') || text.contains('پنجشنبه و جمعه') || text.contains('پنج‌شنبه و جمعه')) {
      recurrenceType = 'CUSTOM_DAYS';
      weekdays = {4, 5};
      for (final m in RegExp(r'(?<![\p{L}\p{N}])(?:آخر هفته|پنجشنبه و جمعه|پنج‌شنبه و جمعه)(?![\p{L}\p{N}])', unicode: true).allMatches(text)) addSpan(m);
    } else {
      final intervalDaysRegex = RegExp(r'هر\s+(\d+)\s+روز');
      final mDays = intervalDaysRegex.firstMatch(text);
      if (mDays != null) {
        recurrenceType = 'INTERVAL_DAYS';
        intervalDays = int.parse(mDays.group(1)!);
        addSpan(mDays);
      } else {
        final intervalHoursRegex = RegExp(r'هر\s+(\d+)\s+ساعت');
        final mHours = intervalHoursRegex.firstMatch(text);
        if (mHours != null) {
          recurrenceType = 'INTERVAL_HOURS';
          intervalHours = int.parse(mHours.group(1)!);
          addSpan(mHours);
        }
      }
    }

    if (recurrenceType == 'EVERY_DAY') {
      final detectedDays = <int>{};
      final dayMap = {
        'شنبه': 6, 'یکشنبه': 7, 'یک‌شنبه': 7, 'دوشنبه': 1, 'سه شنبه': 2, 'سه‌شنبه': 2,
        'چهارشنبه': 3, 'پنجشنبه': 4, 'پنج‌شنبه': 4, 'جمعه': 5,
      };
      for (final e in dayMap.entries) {
        final m = RegExp('(?<![\\p{L}\\p{N}])${e.key}(?![\\p{L}\\p{N}])', unicode: true).firstMatch(text);
        if (m != null) {
          detectedDays.add(e.value);
          addSpan(m);
        }
      }
      if (detectedDays.isNotEmpty) {
        recurrenceType = 'CUSTOM_DAYS';
        weekdays = detectedDays;
      }
    }

    if (timeOfDay != null || daysOffset != null || recurrenceType != 'EVERY_DAY' || weekdays != null || targetDurationMinutes != null) {
      final extraKeywords = ['ساعت', 'صبح', 'عصر', 'شب', 'ظهر', 'بامداد', 'یادآور', 'اعلان', 'کار', 'وظیفه', 'هشدار', 'ثبت', 'ایجاد', 'افزودن'];
      for (final word in extraKeywords) {
        for (final m in RegExp('(?<![\\p{L}\\p{N}])$word(?![\\p{L}\\p{N}])', unicode: true).allMatches(text)) {
          addSpan(m);
        }
      }
    }

    // Clean title using spans
    spansToRemove.sort((a, b) => b.start.compareTo(a.start));
    
    // Resolve overlaps
    final mergedSpans = <({int start, int end})>[];
    for (final s in spansToRemove) {
      if (mergedSpans.isEmpty) {
        mergedSpans.add(s);
      } else {
        final last = mergedSpans.last;
        if (s.end >= last.start) {
          // Overlap, merge
          mergedSpans[mergedSpans.length - 1] = (
            start: s.start < last.start ? s.start : last.start,
            end: s.end > last.end ? s.end : last.end
          );
        } else {
          mergedSpans.add(s);
        }
      }
    }

    var clean = text;
    for (final s in mergedSpans) {
      clean = clean.replaceRange(s.start, s.end, ' ');
    }
    
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) {
      clean = text.trim();
    }

    return QuickAddResult(
      title: clean,
      itemType: itemType,
      timeOfDay: timeOfDay,
      recurrenceType: recurrenceType,
      intervalDays: intervalDays,
      intervalHours: intervalHours,
      weekdays: weekdays,
      daysOffset: daysOffset,
      targetDurationMinutes: targetDurationMinutes,
    );
  }

  static String cleanTitle(
    String text, {
    bool cleanTime = true,
    bool cleanRecurrence = true,
    bool cleanDuration = true,
    bool cleanDate = true,
  }) {
    return parse(text).title;
  }
}
