import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/analysis/agenda_conflict_detector.dart';
import 'package:ritmo/core/domain/agenda/analysis/agenda_gap_calculator.dart';
import 'package:ritmo/core/domain/agenda/analysis/agenda_overload_detector.dart';
import 'package:ritmo/core/domain/agenda/analysis/agenda_suggestion_ranker.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/agenda/sleep_window_resolver.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';

class DayAgendaSnapshotBuilder {
  const DayAgendaSnapshotBuilder({
    this.conflictDetector = const AgendaConflictDetector(),
    this.gapCalculator = const AgendaGapCalculator(),
    this.overloadDetector = const AgendaOverloadDetector(),
    this.suggestionRanker = const AgendaSuggestionRanker(),
  });

  final AgendaConflictDetector conflictDetector;
  final AgendaGapCalculator gapCalculator;
  final AgendaOverloadDetector overloadDetector;
  final AgendaSuggestionRanker suggestionRanker;

  /// C-FIX-1 — تحلیل‌های روز هرگز نباید آیتم‌های روز را قربانی کنند.
  ///
  /// قبلاً چهار تحلیل‌گر (تداخل، فرصت خالی، اضافه‌بار، پیشنهاد) بدون محافظ صدا
  /// زده می‌شدند. صفحهٔ اصلی کل فراخوانی را try/catch می‌کرد و فقط
  /// `todaySnapshot` را از دست می‌داد، ولی تقویم ۶۰ اسنپشات را در یک حلقه در
  /// `JourneyController.loadAgendaRange` می‌ساخت؛ پس تنها یک روزِ خطادار کل
  /// بازه را نابود می‌کرد و نتیجه «برنامه‌ای در بازهٔ پیش‌رو ثبت نشده.» بود،
  /// بدون هیچ پیام خطا. حالا هر تحلیل جدا ایزوله است: در خطا همان بخش خالی
  /// می‌ماند و آیتم‌ها سالم به UI می‌رسند.
  DayAgendaSnapshot buildSnapshot(
    DayAgenda dayAgenda, {
    DateTime? now,
    SleepWindowBlock? sleepWindow,
  }) {
    final currentTime = now ?? DateTime.now();
    final items = dayAgenda.items;
    final ds = dayAgenda.dateStr;

    var completed = 0;
    var remaining = 0;

    for (final item in items) {
      if (item.kind == AgendaItemKind.event ||
          (item.domain == AgendaDomain.cycle &&
              item.kind != AgendaItemKind.reminder)) {
        // Contextual/informational items do not count towards remaining actionable tasks
        continue;
      }
      if (item.isCompleted) {
        completed++;
      } else {
        remaining++;
      }
    }

    var conflicts = const <AgendaConflict>[];
    try {
      conflicts = conflictDetector.detectConflicts(items);
    } catch (e, st) {
      RitmoLog.error(
        'DayAgendaSnapshotBuilder',
        'conflicts failed for $ds',
        e,
        st,
      );
    }

    var freeGaps = const <TimeGap>[];
    try {
      freeGaps = gapCalculator.calculateFreeGaps(
        items,
        now: currentTime,
        sleepWindow: sleepWindow,
      );
    } catch (e, st) {
      RitmoLog.error('DayAgendaSnapshotBuilder', 'freeGaps failed for $ds', e, st);
    }

    var overloadScore = 0.0;
    try {
      overloadScore = overloadDetector.calculateOverloadScore(items);
    } catch (e, st) {
      RitmoLog.error('DayAgendaSnapshotBuilder', 'overload failed for $ds', e, st);
    }

    var suggestions = const <AgendaSuggestion>[];
    try {
      suggestions = suggestionRanker.generateSuggestions(
        items: items,
        conflicts: conflicts,
        freeGaps: freeGaps,
        overloadScore: overloadScore,
        now: currentTime,
        sleepWindow: sleepWindow,
      );
    } catch (e, st) {
      RitmoLog.error(
        'DayAgendaSnapshotBuilder',
        'suggestions failed for $ds',
        e,
        st,
      );
    }

    AgendaItem? previous;
    AgendaItem? current;
    AgendaItem? next;
    AgendaItem? afterNext;

    try {
      final timedItems = items.where((i) => i.isTimed).toList();
      timedItems.sort((a, b) {
        final aM = TimeOfDayMinutes.tryParse(a.timeOfDay) ?? 0;
        final bM = TimeOfDayMinutes.tryParse(b.timeOfDay) ?? 0;
        return aM.compareTo(bM);
      });

      final currentMinutes = (currentTime.hour * 60) + currentTime.minute;

      for (int i = 0; i < timedItems.length; i++) {
        final item = timedItems[i];
        final startMinutes = TimeOfDayMinutes.tryParse(item.timeOfDay) ?? 0;
        var duration = item.durationMinutes ?? 30;
        if (duration <= 0) duration = 30;
        final endMinutes = startMinutes + duration;

        if (endMinutes <= currentMinutes ||
            (startMinutes <= currentMinutes && item.isCompleted)) {
          previous = item;
        }

        if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
          if (!item.isCompleted && current == null) {
            current = item;
            if (i > 0) {
              previous = timedItems[i - 1];
            }
          }
        } else if (startMinutes > currentMinutes) {
          if (!item.isCompleted) {
            if (next == null) {
              next = item;
            } else if (afterNext == null && item.id != next.id) {
              afterNext = item;
            }
          }
        }
      }

      // اگر به دلیل اتمام زودهنگام کار، current خالی شد اما کارهای آینده وجود دارند
      if (next == null) {
        for (final item in timedItems) {
          final startMinutes = TimeOfDayMinutes.tryParse(item.timeOfDay) ?? 0;
          if (!item.isCompleted && startMinutes > currentMinutes) {
            if (next == null) {
              next = item;
            } else if (afterNext == null && item.id != next.id) {
              afterNext = item;
              break;
            }
          }
        }
      }
    } catch (e, st) {
      RitmoLog.error('DayAgendaSnapshotBuilder', 'now/next failed for $ds', e, st);
    }

    return DayAgendaSnapshot(
      dayAgenda: dayAgenda,
      completedCount: completed,
      remainingCount: remaining,
      freeGaps: freeGaps,
      conflicts: conflicts,
      overloadScore: overloadScore,
      previousActivity: previous,
      currentActivity: current,
      nextActivity: next,
      afterNextActivity: afterNext,
      suggestions: suggestions,
      sleepWindow: sleepWindow,
      enabledDomains: dayAgenda.enabledDomains,
    );
  }
}
