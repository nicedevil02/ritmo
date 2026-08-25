// C-04: CycleDataDoctor diagnostic tool.
// Inspects cycle data integrity across cycle_periods, cycle_day_logs, legacy cycle_logs, and app_settings.
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite/sqflite.dart';

class CycleDataDiagnosis {
  final int overlappingPeriodsCount;
  final int invalidDateOrderCount;
  final int futureEndDateCount;
  final int staleOpenPeriodsCount;
  final int unmigratedLegacyLogsCount;
  final int outOfSyncSettingsCount;

  const CycleDataDiagnosis({
    required this.overlappingPeriodsCount,
    required this.invalidDateOrderCount,
    required this.futureEndDateCount,
    required this.staleOpenPeriodsCount,
    required this.unmigratedLegacyLogsCount,
    required this.outOfSyncSettingsCount,
  });

  int get totalIssues =>
      overlappingPeriodsCount +
      invalidDateOrderCount +
      futureEndDateCount +
      staleOpenPeriodsCount +
      unmigratedLegacyLogsCount +
      outOfSyncSettingsCount;

  bool get isHealthy => totalIssues == 0;

  Map<String, int> toMap() => {
    'overlappingPeriodsCount': overlappingPeriodsCount,
    'invalidDateOrderCount': invalidDateOrderCount,
    'futureEndDateCount': futureEndDateCount,
    'staleOpenPeriodsCount': staleOpenPeriodsCount,
    'unmigratedLegacyLogsCount': unmigratedLegacyLogsCount,
    'outOfSyncSettingsCount': outOfSyncSettingsCount,
  };

  @override
  String toString() =>
      'CycleDataDiagnosis(totalIssues: $totalIssues, isHealthy: $isHealthy, details: ${toMap()})';
}

class CycleDataDoctor {
  const CycleDataDoctor._();

  /// Inspects [db] and returns a detailed data diagnosis.
  /// [now] can be injected for deterministic testing (defaults to CycleClock.now).
  static Future<CycleDataDiagnosis> diagnose(
    DatabaseExecutor db, {
    DateTime? now,
  }) async {
    final effectiveNow = now ?? CycleClock.now;
    final todayStr = CycleDateContract.toDayKey(effectiveNow);
    final cleanToday = CycleDateContract.cleanDate(effectiveNow);

    int overlappingPeriodsCount = 0;
    int invalidDateOrderCount = 0;
    int futureEndDateCount = 0;
    int staleOpenPeriodsCount = 0;
    int unmigratedLegacyLogsCount = 0;
    int outOfSyncSettingsCount = 0;

    // 1. Check if cycle_periods table exists
    final periodTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='cycle_periods'",
    );

    if (periodTables.isNotEmpty) {
      final periods = await db.query('cycle_periods', orderBy: 'startDate ASC');

      // Parsed periods representation
      final parsedList = <_PeriodInterval>[];
      for (final row in periods) {
        final id = row['id']?.toString() ?? '';
        final startRaw = row['startDate']?.toString();
        final endRaw = row['endDate']?.toString();

        final start = CycleDateContract.parseDayKey(startRaw);
        if (start == null) continue;

        DateTime? end;
        if (endRaw != null && endRaw.trim().isNotEmpty) {
          end = CycleDateContract.parseDayKey(endRaw);
          if (end != null) {
            // Check endDate < startDate
            if (end.isBefore(start)) {
              invalidDateOrderCount++;
            }
            // Check endDate in future
            if (CycleDateContract.toDayKey(end).compareTo(todayStr) > 0) {
              futureEndDateCount++;
            }
          }
        } else {
          // Open period (endDate is null)
          final daysOpen = CycleDateContract.daysBetween(start, cleanToday);
          if (daysOpen > CycleSettings.maxPlausiblePeriodDays) {
            staleOpenPeriodsCount++;
          }
        }

        parsedList.add(_PeriodInterval(id: id, start: start, end: end));
      }

      // Check overlapping periods
      for (int i = 0; i < parsedList.length; i++) {
        for (int j = i + 1; j < parsedList.length; j++) {
          final p1 = parsedList[i];
          final p2 = parsedList[j];

          // Effective end of p1 and p2 using contract
          final p1End = CycleDateContract.effectiveEnd(
            start: p1.start,
            end: p1.end,
            today: cleanToday,
            maxPlausibleDays: CycleSettings.maxPlausiblePeriodDays,
          );
          final p2End = CycleDateContract.effectiveEnd(
            start: p2.start,
            end: p2.end,
            today: cleanToday,
            maxPlausibleDays: CycleSettings.maxPlausiblePeriodDays,
          );

          if (CycleDateContract.overlaps(p1.start, p1End, p2.start, p2End)) {
            overlappingPeriodsCount++;
          }
        }
      }
    }

    // 2. Check unmigrated legacy cycle_logs
    final legacyTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='cycle_logs'",
    );

    if (legacyTables.isNotEmpty && periodTables.isNotEmpty) {
      final legacyRows = await db.query('cycle_logs');
      final periodRows = await db.query('cycle_periods');

      final canonicalStartDates = <String>{};
      for (final p in periodRows) {
        final s = p['startDate']?.toString();
        final parsed = CycleDateContract.parseDayKey(s);
        if (parsed != null) {
          canonicalStartDates.add(CycleDateContract.toDayKey(parsed));
        }
      }

      for (final legacy in legacyRows) {
        final legacyStart = legacy['cycleStartDate']?.toString();
        final parsedLegacy = CycleDateContract.parseDayKey(legacyStart);
        if (parsedLegacy != null) {
          final key = CycleDateContract.toDayKey(parsedLegacy);
          if (!canonicalStartDates.contains(key)) {
            unmigratedLegacyLogsCount++;
          }
        }
      }
    }

    // 3. Check out-of-sync settings
    final appSettingsTable = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='app_settings'",
    );

    if (appSettingsTable.isNotEmpty) {
      final settingsList = await db.query('app_settings');
      final settings = {
        for (final s in settingsList)
          if (s['key'] != null)
            s['key'].toString(): s['value']?.toString() ?? '',
      };

      // Check cycle length out of sync: canonical is keyCycleLength ('cycle_length_days')
      final canonCycle = settings[CycleSettings.keyCycleLength];
      final legacyCycle1 = settings['cycle_avg_length'];
      final legacyCycle2 = settings['user_cycle_length'];
      if ((legacyCycle1 != null &&
              legacyCycle1.isNotEmpty &&
              canonCycle != null &&
              legacyCycle1 != canonCycle) ||
          (legacyCycle2 != null &&
              legacyCycle2.isNotEmpty &&
              canonCycle != null &&
              legacyCycle2 != canonCycle)) {
        outOfSyncSettingsCount++;
      }

      // Check period duration out of sync: canonical is keyPeriodDuration ('period_duration_days')
      final canonPeriod = settings[CycleSettings.keyPeriodDuration];
      final legacyPeriod1 = settings['cycle_avg_period'];
      final legacyPeriod2 = settings['period_avg_duration'];
      final legacyPeriod3 = settings['user_period_duration'];
      if ((legacyPeriod1 != null &&
              legacyPeriod1.isNotEmpty &&
              canonPeriod != null &&
              legacyPeriod1 != canonPeriod) ||
          (legacyPeriod2 != null &&
              legacyPeriod2.isNotEmpty &&
              canonPeriod != null &&
              legacyPeriod2 != canonPeriod) ||
          (legacyPeriod3 != null &&
              legacyPeriod3.isNotEmpty &&
              canonPeriod != null &&
              legacyPeriod3 != canonPeriod)) {
        outOfSyncSettingsCount++;
      }

      // Check pregnancy mode out of sync: canonical is keyPregnancyMode ('cycle_pregnancy_mode')
      final canonPreg = settings[CycleSettings.keyPregnancyMode];
      final legacyPreg1 = settings['pregnancy_mode'];
      final legacyPreg2 = settings['cycle_is_pregnant'];
      if ((legacyPreg1 != null &&
              legacyPreg1.isNotEmpty &&
              canonPreg != null &&
              legacyPreg1 != canonPreg) ||
          (legacyPreg2 != null &&
              legacyPreg2.isNotEmpty &&
              canonPreg != null &&
              legacyPreg2 != canonPreg)) {
        outOfSyncSettingsCount++;
      }
    }

    return CycleDataDiagnosis(
      overlappingPeriodsCount: overlappingPeriodsCount,
      invalidDateOrderCount: invalidDateOrderCount,
      futureEndDateCount: futureEndDateCount,
      staleOpenPeriodsCount: staleOpenPeriodsCount,
      unmigratedLegacyLogsCount: unmigratedLegacyLogsCount,
      outOfSyncSettingsCount: outOfSyncSettingsCount,
    );
  }
}

class _PeriodInterval {
  final String id;
  final DateTime start;
  final DateTime? end;

  const _PeriodInterval({required this.id, required this.start, this.end});
}
