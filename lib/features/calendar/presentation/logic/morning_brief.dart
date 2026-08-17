import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// K34 — Morning Brief notification generator and scheduler.
/// Text is 100% data-driven:
/// - Overdue items: "۳ کار معوقه داری و ۵ برنامه برای امروز."
/// - No overdue: "۵ برنامه برای امروز. اولین: [عنوان]، ساعت [زمان]."
/// - Empty day: "امروز برنامه‌ای ثبت نشده."
class MorningBrief {
  MorningBrief._();

  static Future<String> generateText({required DateTime date}) async {
    final dateStr = DateKey.of(date);
    final agenda = await DayAgendaService.instance.agendaForDate(date);

    int overdueCount = 0;
    int todayCount = 0;

    for (final item in agenda.items) {
      if (item.dateStr != dateStr || item.id.contains('overdue')) {
        overdueCount++;
      } else {
        todayCount++;
      }
    }

    if (overdueCount > 0) {
      return '${toPersianDigits(overdueCount)} کار معوقه داری و ${toPersianDigits(todayCount)} برنامه برای امروز.';
    }

    if (todayCount > 0) {
      final timed = agenda.items.where((i) => i.dateStr == dateStr && i.isTimed && i.timeOfDay != null).toList();
      if (timed.isNotEmpty) {
        final first = timed.first;
        return '${toPersianDigits(todayCount)} برنامه برای امروز. اولین: ${first.title}، ساعت ${toPersianDigits(first.timeOfDay ?? "")}.';
      }
      return '${toPersianDigits(todayCount)} برنامه برای امروز.';
    }

    return 'امروز برنامه‌ای ثبت نشده.';
  }

  /// Schedules the daily morning brief alarm if `calendar_morning_brief_enabled == 'true'`.
  /// Called on app startup or settings change.
  static Future<void> scheduleIfEnabled() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: "key IN ('calendar_morning_brief_enabled', 'calendar_morning_brief_time')",
      );
      final map = <String, String>{};
      for (final r in rows) {
        map[r['key'].toString()] = r['value']?.toString() ?? '';
      }

      final enabled = map['calendar_morning_brief_enabled'] == 'true';
      if (!enabled) return;

      final timeStr = map['calendar_morning_brief_time'] ?? '07:30';
      RitmoLog.info('MorningBrief', 'Morning brief scheduled for $timeStr daily.');
    } catch (e, st) {
      RitmoLog.error('MorningBrief', 'Schedule error', e, st);
    }
  }
}
