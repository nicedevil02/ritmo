import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/logic/worship_occasions_data.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// Occasion item structure for calendar display.
class CalendarOccasion {
  const CalendarOccasion({
    required this.title,
    required this.isHoliday,
    required this.category,
    this.recommendedAmal,
  });

  final String title;
  final bool isHoliday;
  final String category;
  final String? recommendedAmal;
}

/// K41 — Loads worship & Jalali/Hijri occasions for a given date.
class OccasionsCalendarSource {
  OccasionsCalendarSource._();

  static List<CalendarOccasion> occasionsForDate(DateTime date) {
    try {
      final solar = Jalali.fromDateTime(date);
      final hijriDate = WorshipEngine.instance.hijriFor(date);
      final list = WorshipOccasionsData.getOccasionsForDay(solar, hijriDate);

      final result = <CalendarOccasion>[];

      for (final occ in list) {
        result.add(
          CalendarOccasion(
            title: occ.title,
            isHoliday: occ.isHoliday,
            category: occ.category.name,
            recommendedAmal: occ.recommendedAmal,
          ),
        );
      }

      return result;
    } catch (e, st) {
      RitmoLog.error(
        'OccasionsCalendarSource',
        'getOccasions failed for $date',
        e,
        st,
      );
      return const [];
    }
  }
}
