import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';
import 'package:sqflite/sqflite.dart';

/// Represents a normalized sleep / rest window block for timeline presentation.
class SleepWindowBlock {
  const SleepWindowBlock({
    required this.startMinutes,
    required this.endMinutes,
    required this.crossesMidnight,
    this.label,
    this.bedtime,
    this.wakeTime,
  });

  /// Start minute of the day (0..1439), e.g. 1410 for 23:30.
  final int startMinutes;

  /// End minute of the day (0..1439 or >=1440 if normalized past midnight), e.g. 420 or 1860.
  final int endMinutes;

  /// True if bedtime is on the target date and wake time falls on the next calendar day.
  final bool crossesMidnight;

  /// Optional label for UI rendering (e.g., "پنجره خواب" / "Sleep Window").
  final String? label;

  /// Bedtime string 'HH:mm'.
  final String? bedtime;

  /// Wake time string 'HH:mm'.
  final String? wakeTime;

  /// Duration of the sleep window in minutes.
  int get durationMinutes {
    final diff = endMinutes - startMinutes;
    return diff > 0 ? diff : diff + 1440;
  }
}

/// Helper service for resolving sleep and rest windows from settings and plan days.
class SleepWindowResolver {
  const SleepWindowResolver();

  /// Resolves the planned sleep window for [dateStr] reading `sleep_plan_days` with fallback to settings.
  Future<SleepWindowBlock?> resolveForDay({
    required Database db,
    required Map<String, String> settingsMap,
    required String dateStr,
    String defaultLabel = 'پنجره خواب',
  }) async {
    final isEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_sleep_enabled',
    );
    final showSleepBand = settingsMap['calendar_show_sleep_band'] != 'false';

    if (!isEnabled || !showSleepBand) {
      return null;
    }

    try {
      final rows = await db.rawQuery(
        '''
        SELECT plannedBedtimeMin, plannedWakeMin
        FROM sleep_plan_days
        WHERE date = ?
        LIMIT 1
      ''',
        [dateStr],
      );

      if (rows.isNotEmpty) {
        final bedMin = rows.first['plannedBedtimeMin'] as int?;
        final wakeMin = rows.first['plannedWakeMin'] as int?;
        if (bedMin != null && wakeMin != null && bedMin != wakeMin) {
          final block = resolveFromMinutes(
            plannedBedtimeMin: bedMin,
            plannedWakeMin: wakeMin,
            label: defaultLabel,
          );
          if (block != null) return block;
        }
      }
    } catch (_) {
      // Fallback to settings on query error
    }

    return resolveFromSettings(settingsMap, defaultLabel: defaultLabel);
  }

  /// Resolves the sleep window block for a given date using [settingsMap].
  /// Fails gracefully and returns `null` if sleep data is unavailable or disabled.
  SleepWindowBlock? resolveFromSettings(
    Map<String, String> settingsMap, {
    String defaultLabel = 'پنجره خواب',
  }) {
    final isEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_sleep_enabled',
    );
    final showSleepBand = settingsMap['calendar_show_sleep_band'] != 'false';
    final bedtime = settingsMap['sleep_target_bedtime'];
    final wakeTime = settingsMap['sleep_target_wake'];

    if ((!isEnabled || !showSleepBand) &&
        (bedtime == null || wakeTime == null)) {
      return null;
    }

    return resolveFromTimes(
      bedtime: bedtime ?? '23:30',
      wakeTime: wakeTime ?? '07:00',
      label: defaultLabel,
    );
  }

  /// Resolves a [SleepWindowBlock] from raw minute values (0..1439).
  SleepWindowBlock? resolveFromMinutes({
    required int plannedBedtimeMin,
    required int plannedWakeMin,
    String? label,
  }) {
    if (plannedBedtimeMin < 0 ||
        plannedBedtimeMin >= 1440 ||
        plannedWakeMin < 0 ||
        plannedWakeMin >= 1440 ||
        plannedBedtimeMin == plannedWakeMin) {
      return null;
    }

    final crossesMidnight = plannedBedtimeMin > plannedWakeMin;
    final normalizedEndM = crossesMidnight
        ? plannedWakeMin + 1440
        : plannedWakeMin;

    final bedH = plannedBedtimeMin ~/ 60;
    final bedM = plannedBedtimeMin % 60;
    final wakeH = plannedWakeMin ~/ 60;
    final wakeM = plannedWakeMin % 60;

    final bedStr =
        '${bedH.toString().padLeft(2, '0')}:${bedM.toString().padLeft(2, '0')}';
    final wakeStr =
        '${wakeH.toString().padLeft(2, '0')}:${wakeM.toString().padLeft(2, '0')}';

    return SleepWindowBlock(
      startMinutes: plannedBedtimeMin,
      endMinutes: normalizedEndM,
      crossesMidnight: crossesMidnight,
      label: label,
      bedtime: bedStr,
      wakeTime: wakeStr,
    );
  }

  /// Pure computation helper to resolve a [SleepWindowBlock] from time strings ('HH:mm').
  SleepWindowBlock? resolveFromTimes({
    required String? bedtime,
    required String? wakeTime,
    String? label,
  }) {
    if (bedtime == null || wakeTime == null) return null;

    final startM = TimeOfDayMinutes.tryParse(bedtime);
    final endM = TimeOfDayMinutes.tryParse(wakeTime);

    if (startM == null || endM == null || startM == endM) return null;

    final crossesMidnight = startM > endM;
    final normalizedEndM = crossesMidnight ? endM + 1440 : endM;

    return SleepWindowBlock(
      startMinutes: startM,
      endMinutes: normalizedEndM,
      crossesMidnight: crossesMidnight,
      label: label,
      bedtime: bedtime,
      wakeTime: wakeTime,
    );
  }
}
