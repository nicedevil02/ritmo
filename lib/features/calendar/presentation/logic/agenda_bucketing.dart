import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/courses/logic/course_scheduler.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// K19 — Agenda Scale Bucketing (pure function, no DateTime.now() inside)
///
/// هفتهٔ شمسی: شنبه (Saturday) تا جمعه (Friday)
/// از CourseScheduler.getSaturdayOfWeek برای محاسبهٔ مرز هفته استفاده می‌کنیم.
enum AgendaBucket { overdue, today, tomorrow, thisWeek, nextWeek, later }

/// Represents an entry in a compressed agenda view (either a single item or a recurring series group).
sealed class AgendaEntry {}

class AgendaSingle extends AgendaEntry {
  AgendaSingle(this.item);
  final AgendaItem item;
}

class AgendaSeries extends AgendaEntry {
  AgendaSeries({
    required this.representative,
    required this.instances,
    required this.recurrenceLabel,
  });

  final AgendaItem representative;
  final List<AgendaItem> instances;
  final String recurrenceLabel; // «هر روز» / «۵ روز از ۷» / «روزهای کاری» / «شنبه‌ها»

  int get completedCount => instances.where((i) => i.isCompleted).length;
  int get totalCount => instances.length;
}

/// برچسب فارسی هر سطل
String bucketLabelFa(AgendaBucket b) {
  switch (b) {
    case AgendaBucket.overdue:
      return 'معوقه';
    case AgendaBucket.today:
      return 'امروز';
    case AgendaBucket.tomorrow:
      return 'فردا';
    case AgendaBucket.thisWeek:
      return 'این هفته';
    case AgendaBucket.nextWeek:
      return 'هفتهٔ بعد';
    case AgendaBucket.later:
      return 'بعدتر';
  }
}

/// Buckets all agenda items from [snapshots] relative to [now].
///
/// Rules (Shamsi week: Saturday → Friday):
/// - overdue   : dateStr < today  AND  completion != done/skipped
/// - today     : dateStr == today
/// - tomorrow  : dateStr == today + 1
/// - thisWeek  : dateStr in (tomorrow, endOfThisWeek]
/// - nextWeek  : dateStr in [startOfNextWeek, endOfNextWeek]
/// - later     : beyond nextWeek
///
/// Guarantee: no item appears in two buckets simultaneously.
Map<AgendaBucket, List<AgendaItem>> bucketRange(
  Map<String, DayAgendaSnapshot> snapshots, {
  required DateTime now,
}) {
  final today = DateKey.dayOf(now);
  final tomorrow = DateKey.addDays(today, 1);

  // Shamsi-week boundaries
  final thisSat = CourseScheduler.getSaturdayOfWeek(today);
  final thisFri = DateKey.addDays(thisSat, 6);
  final nextSat = DateKey.addDays(thisFri, 1);
  final nextFri = DateKey.addDays(nextSat, 6);

  // Post-tomorrow start of thisWeek: day after tomorrow up to end of this week
  final thisWeekStart = DateKey.addDays(tomorrow, 1);

  final result = <AgendaBucket, List<AgendaItem>>{
    AgendaBucket.overdue: [],
    AgendaBucket.today: [],
    AgendaBucket.tomorrow: [],
    AgendaBucket.thisWeek: [],
    AgendaBucket.nextWeek: [],
    AgendaBucket.later: [],
  };

  // Iterate snapshots in chronological order
  final sortedEntries = snapshots.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  for (final entry in sortedEntries) {
    final dateStr = entry.key;
    final date = DateKey.parse(dateStr);
    if (date == null) {
      RitmoLog.error('AgendaBucketing', 'Invalid dateKey in snapshots: $dateStr');
      continue;
    }
    final dateOnly = DateKey.dayOf(date);

    for (final item in entry.value.items) {
      final isDone = item.completion == AgendaCompletion.done ||
          item.completion == AgendaCompletion.skipped;

      if (dateOnly.isBefore(today)) {
        // Past days — only undone items become overdue
        if (!isDone) {
          result[AgendaBucket.overdue]!.add(item);
        }
      } else if (dateOnly.isAtSameMomentAs(today)) {
        result[AgendaBucket.today]!.add(item);
      } else if (dateOnly.isAtSameMomentAs(tomorrow)) {
        result[AgendaBucket.tomorrow]!.add(item);
      } else if (!dateOnly.isBefore(thisWeekStart) &&
          !dateOnly.isAfter(thisFri)) {
        result[AgendaBucket.thisWeek]!.add(item);
      } else if (!dateOnly.isBefore(nextSat) &&
          !dateOnly.isAfter(nextFri)) {
        result[AgendaBucket.nextWeek]!.add(item);
      } else if (dateOnly.isAfter(nextFri)) {
        result[AgendaBucket.later]!.add(item);
      }
    }
  }

  return result;
}

/// Computes the number of days represented in a given bucket.
int calculateDaysInBucket(
  AgendaBucket bucket, {
  required DateTime now,
  required List<AgendaItem> items,
}) {
  switch (bucket) {
    case AgendaBucket.overdue:
    case AgendaBucket.today:
    case AgendaBucket.tomorrow:
      return 1;
    case AgendaBucket.thisWeek:
      final today = DateKey.dayOf(now);
      final tomorrow = DateKey.addDays(today, 1);
      final thisSat = CourseScheduler.getSaturdayOfWeek(today);
      final thisFri = DateKey.addDays(thisSat, 6);
      final thisWeekStart = DateKey.addDays(tomorrow, 1);
      // سطل خالی است (مثلاً امروز پنج‌شنبه یا جمعه است و این سطل در تقویم امروز وجود ندارد)
      if (thisWeekStart.isAfter(thisFri)) return 0;
      return thisFri.difference(thisWeekStart).inDays + 1;
    case AgendaBucket.nextWeek:
      return 7;
    case AgendaBucket.later:
      if (items.isEmpty) return 7;
      final dates = <DateTime>[];
      for (final item in items) {
        final d = DateKey.parse(item.dateStr);
        if (d != null) {
          dates.add(DateKey.dayOf(d));
        } else {
          RitmoLog.error('AgendaBucketing', 'Invalid item dateStr: ${item.dateStr}');
        }
      }
      if (dates.isEmpty) return 7;
      dates.sort();
      final minDate = dates.first;
      final maxDate = dates.last;
      final diff = maxDate.difference(minDate).inDays + 1;
      return diff > 0 ? diff : 1;
  }
}

/// Computes Persian recurrence label for a series based on its occurrence dates and bucket days count.
String calculateRecurrenceLabel(List<DateTime> dates, int daysInBucket) {
  if (dates.isEmpty) return '';
  final uniqueDates = dates.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()
    ..sort();
  final n = uniqueDates.length;
  final m = daysInBucket > 0 ? daysInBucket : n;

  if (n > m) {
    // نمی‌تواند بیشتر از تعداد روزهای سطل باشد؛ داده‌ها ناسازگارند.
    RitmoLog.error('AgendaBucketing', 'n=$n > m=$m in recurrence label: bucket span mismatch');
    return 'تکرارشونده';
  }

  if (n == m) {
    return 'هر روز';
  }

  // Check if all 5 Shamsi workdays (Saturday=1 to Wednesday=5) are present
  final jalaliDates = uniqueDates.map((d) => Jalali.fromDateTime(d)).toList();
  final weekdaySet = jalaliDates.map((j) => j.weekDay).toSet();
  if (weekdaySet.length == 5 && weekdaySet.every((w) => w >= 1 && w <= 5)) {
    return 'روزهای کاری';
  }

  // Check if all dates share the same weekday
  final firstWd = jalaliDates.first.weekDay;
  if (jalaliDates.every((j) => j.weekDay == firstWd)) {
    const weekdayPlurals = [
      'شنبه‌ها',
      'یک‌شنبه‌ها',
      'دوشنبه‌ها',
      'سه‌شنبه‌ها',
      'چهارشنبه‌ها',
      'پنج‌شنبه‌ها',
      'جمعه‌ها'
    ];
    final idx = (firstWd - 1).clamp(0, 6);
    return weekdayPlurals[idx];
  }

  return '${toPersianDigits(n)} روز از ${toPersianDigits(m)}';
}

/// Collapses recurring daily items in [bucketItems] into [AgendaSeries] entries
/// if their count >= [minOccurrences] (default 3). Unique items remain as [AgendaSingle].
///
/// Pure function (no DateTime.now() inside).
/// Returns a list where [AgendaSingle] items appear FIRST (top) followed by [AgendaSeries].
List<AgendaEntry> collapseRecurringSeries(
  List<AgendaItem> bucketItems, {
  required int daysInBucket,
  int minOccurrences = 3,
}) {
  if (bucketItems.isEmpty) return const [];

  final grouped = <String, List<AgendaItem>>{};
  for (final item in bucketItems) {
    grouped.putIfAbsent(item.recurrenceKey, () => []).add(item);
  }

  final singles = <AgendaSingle>[];
  final seriesList = <AgendaSeries>[];

  for (final entry in grouped.entries) {
    final instances = entry.value;
    if (instances.length >= minOccurrences) {
      instances.sort((a, b) {
        final dateCmp = a.dateStr.compareTo(b.dateStr);
        if (dateCmp != 0) return dateCmp;
        return (a.timeOfDay ?? '').compareTo(b.timeOfDay ?? '');
      });

      final dates = <DateTime>[];
      for (final inst in instances) {
        final d = DateKey.parse(inst.dateStr);
        if (d != null) {
          dates.add(DateKey.dayOf(d));
        } else {
          RitmoLog.error('AgendaBucketing', 'Invalid dateKey in series instance: ${inst.dateStr}');
        }
      }

      final rep = instances.firstWhere(
        (i) => !i.isCompleted,
        orElse: () => instances.first,
      );

      final label = rep.recurrenceLabelFa ?? calculateRecurrenceLabel(dates, daysInBucket);

      seriesList.add(AgendaSeries(
        representative: rep,
        instances: instances,
        recurrenceLabel: label,
      ));
    } else {
      for (final item in instances) {
        singles.add(AgendaSingle(item));
      }
    }
  }

  // Sort singles chronologically, then by time/priority
  singles.sort((a, b) {
    final dateCmp = a.item.dateStr.compareTo(b.item.dateStr);
    if (dateCmp != 0) return dateCmp;
    if (a.item.isTimed && b.item.isTimed) {
      return (a.item.timeOfDay ?? '').compareTo(b.item.timeOfDay ?? '');
    } else if (a.item.isTimed) {
      return -1;
    } else if (b.item.isTimed) {
      return 1;
    }
    return b.item.priority.compareTo(a.item.priority);
  });

  // Sort series chronologically by representative dateStr / timeOfDay
  seriesList.sort((a, b) {
    final dateCmp = a.representative.dateStr.compareTo(b.representative.dateStr);
    if (dateCmp != 0) return dateCmp;
    return (a.representative.timeOfDay ?? '').compareTo(b.representative.timeOfDay ?? '');
  });

  return [...singles, ...seriesList];
}

/// Groups items within a bucket by their dateStr for sub-day headings.
/// Used by `thisWeek`, `nextWeek`, `later` buckets.
Map<String, List<AgendaItem>> groupByDate(List<AgendaItem> items) {
  final map = <String, List<AgendaItem>>{};
  for (final item in items) {
    map.putIfAbsent(item.dateStr, () => []).add(item);
  }
  return map;
}

/// Persian label for a date, used as sub-group heading inside thisWeek/nextWeek/later.
String daySubGroupLabel(String dateStr) {
  final date = DateKey.parse(dateStr);
  if (date == null) {
    RitmoLog.error('AgendaBucketing', 'Invalid dateStr for subGroup label: $dateStr');
    return dateStr;
  }
  final j = Jalali.fromDateTime(date);
  const weekdays = ['شنبه', 'یک‌شنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه'];
  // Jalali weekday: 1=Saturday, 7=Friday
  final wdLabel = weekdays[(j.weekDay - 1).clamp(0, 6)];
  return '$wdLabel ${j.day} ${j.formatter.mN}';
}

