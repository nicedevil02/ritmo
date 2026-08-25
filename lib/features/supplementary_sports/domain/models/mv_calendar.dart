/// Central Calendar Converter for Ritmo Sports & Movement Domain.
///
/// Bridges Dart's [DateTime.weekday] (1=Monday..7=Sunday) and Persian/Ritmo
/// Sat0-index (0=Saturday..6=Friday).
///
/// Prevents D-08 weekday calculation divergence across all engines and presentations.
class MvCalendar {
  const MvCalendar._();

  /// Converts Sat0 index (0=Saturday..6=Friday) to Dart's DateTime.weekday (1=Mon..7=Sun).
  static int sat0ToDartWeekday(int sat0) {
    assert(sat0 >= 0 && sat0 <= 6, 'sat0 must be 0..6');
    // Sat=0 -> 6
    // Sun=1 -> 7
    // Mon=2 -> 1
    // Tue=3 -> 2
    // Wed=4 -> 3
    // Thu=5 -> 4
    // Fri=6 -> 5
    if (sat0 == 0) return DateTime.saturday; // 6
    if (sat0 == 1) return DateTime.sunday; // 7
    return sat0 - 1; // Mon(2)->1, Tue(3)->2, Wed(4)->3, Thu(5)->4, Fri(6)->5
  }

  /// Converts Dart's DateTime.weekday (1=Monday..7=Sunday) to Sat0 index (0=Saturday..6=Friday).
  static int dartWeekdayToSat0(int weekday) {
    assert(weekday >= 1 && weekday <= 7, 'weekday must be 1..7');
    if (weekday == DateTime.saturday) return 0;
    if (weekday == DateTime.sunday) return 1;
    return weekday + 1; // Mon(1)->2, Tue(2)->3, Wed(3)->4, Thu(4)->5, Fri(5)->6
  }

  /// Returns the Sat0 index for a given [DateTime].
  static int dateTimeToSat0(DateTime dt) => dartWeekdayToSat0(dt.weekday);

  /// Formats a [DateTime] into local standard ISO date string (`YYYY-MM-DD`).
  static String formatDateIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses a standard ISO date string (`YYYY-MM-DD`) into a local [DateTime].
  static DateTime parseDateIso(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid ISO date string: $iso');
    }
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Returns the date of the Saturday that starts the week containing [dt].
  static DateTime getWeekSaturday(DateTime dt) {
    final sat0 = dateTimeToSat0(dt);
    final cleanDate = DateTime(dt.year, dt.month, dt.day);
    return cleanDate.subtract(Duration(days: sat0));
  }

  /// Returns all 7 dates (Saturday to Friday) for the week containing [dt].
  static List<DateTime> getWeekDays(DateTime dt) {
    final sat = getWeekSaturday(dt);
    return List.generate(7, (index) => sat.add(Duration(days: index)));
  }

  /// Returns all 7 ISO strings (`YYYY-MM-DD`) for the week containing [dt].
  static List<String> getWeekDateIsos(DateTime dt) {
    return getWeekDays(dt).map(formatDateIso).toList();
  }

  /// Calculates the 1-based cycle week from [programStartDate] to [targetDate].
  static int cycleWeekFor({
    required DateTime targetDate,
    required DateTime programStartDate,
    int totalWeeks = 4,
  }) {
    final startSat = getWeekSaturday(programStartDate);
    final targetSat = getWeekSaturday(targetDate);
    final diffDays = targetSat.difference(startSat).inDays;
    final diffWeeks = (diffDays / 7).floor();
    if (diffWeeks < 0) return 1;
    return (diffWeeks % totalWeeks) + 1;
  }

  /// Checks if the given [cycleWeek] is a deload/light week (e.g. every [deloadEveryNWeeks] weeks).
  static bool isDeloadWeek(int cycleWeek, {int deloadEveryNWeeks = 4}) {
    if (deloadEveryNWeeks <= 0) return false;
    return (cycleWeek % deloadEveryNWeeks) == 0;
  }

  /// Returns Persian weekday name from Sat0 index (0=شنبه .. 6=جمعه).
  static String persianWeekdayName(int sat0) {
    switch (sat0) {
      case 0:
        return 'شنبه';
      case 1:
        return 'یک‌شنبه';
      case 2:
        return 'دوشنبه';
      case 3:
        return 'سه‌شنبه';
      case 4:
        return 'چهارشنبه';
      case 5:
        return 'پنج‌شنبه';
      case 6:
        return 'جمعه';
      default:
        return 'شنبه';
    }
  }

  /// Returns short Persian weekday symbol from Sat0 index (ش .. ج).
  static String persianWeekdayShort(int sat0) {
    switch (sat0) {
      case 0:
        return 'ش';
      case 1:
        return 'ی';
      case 2:
        return 'د';
      case 3:
        return 'س';
      case 4:
        return 'چ';
      case 5:
        return 'پ';
      case 6:
        return 'ج';
      default:
        return 'ش';
    }
  }
}
