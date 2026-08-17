import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/analysis/agenda_conflict_detector.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_defaults.dart';

class ConflictChecker {
  static Future<List<AgendaItem>> checkConflicts({
    required String timeStr,
    required int durationMinutes,
    required String dateStr,
    String? ignoreSourceId,
  }) async {
    final startMinutes = TimeOfDayMinutes.tryParse(timeStr);
    if (startMinutes == null) {
      return [];
    }

    try {
      final targetDate = DateKey.parse(dateStr);
      if (targetDate == null) return [];

      final dayAgenda = await DayAgendaService.instance.agendaForDate(
        targetDate,
      );
      final items = dayAgenda.items;

      final dur = durationMinutes <= 0
          ? CalendarDefaults.fallbackDurationMinutes
          : durationMinutes;

      final detector = const AgendaConflictDetector();
      final conflicts = detector.checkCandidate(
        existing: items,
        startMinutes: startMinutes,
        durationMinutes: dur,
        ignoreSourceId: ignoreSourceId,
      );

      return conflicts.map((c) => c.itemA).toList();
    } catch (_) {
      return [];
    }
  }
}
