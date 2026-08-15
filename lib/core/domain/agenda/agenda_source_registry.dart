import 'package:flutter/foundation.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/appointment_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/commitment_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/course_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/cycle_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/event_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/goal_steps_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/konkur_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/medicine_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/routine_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/sports_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/task_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/worship_agenda_source.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:sqflite/sqflite.dart';

/// Context provided to agenda source builders during range loading.
class AgendaSourceLoadContext {
  const AgendaSourceLoadContext({
    required this.db,
    required this.settingsMap,
    required this.start,
    required this.end,
    required this.startStr,
    required this.endStr,
    required this.todayStr,
    required this.options,
    required this.failures,
  });

  final Database db;
  final Map<String, String> settingsMap;
  final DateTime start;
  final DateTime end;
  final String startStr;
  final String endStr;
  final String todayStr;
  final AgendaQueryOptions options;
  final List<String> failures;

  /// Helper to run a source loader inside try/catch, logging and recording failure if it throws.
  Future<T> guardSource<T>(
    String label,
    Future<T> Function() load,
    T Function() fallback,
  ) async {
    try {
      return await load();
    } catch (e, st) {
      RitmoLog.error('AgendaSourceRegistry', 'source "$label" failed', e, st);
      failures.add(label);
      return fallback();
    }
  }
}

/// Registration entry for an agenda source.
class AgendaSourceEntry {
  const AgendaSourceEntry({
    required this.id,
    required this.domains,
    required this.loader,
  });

  final String id;
  final Set<AgendaDomain> domains;
  final Future<AgendaSource?> Function(AgendaSourceLoadContext ctx) loader;
}

/// Central registry of all agenda sources that feed into DayAgendaService.
///
/// Supports default built-in registration as well as test injection seams.
class AgendaSourceRegistry {
  AgendaSourceRegistry._() {
    _registerDefaults();
  }

  static final AgendaSourceRegistry instance = AgendaSourceRegistry._();

  final List<AgendaSourceEntry> _entries = [];

  /// Unmodifiable view of registered entries.
  List<AgendaSourceEntry> get entries => List.unmodifiable(_entries);

  void _registerDefaults() {
    _entries.clear();

    // 1. Routine Agenda Source
    _entries.add(AgendaSourceEntry(
      id: 'routine',
      domains: {AgendaDomain.routine, AgendaDomain.event},
      loader: (ctx) async {
        return ctx.guardSource<AgendaSource>(
          'routine',
          () => RoutineAgendaSource.load(ctx.db, ctx.settingsMap, ctx.startStr, ctx.endStr),
          () => RoutineAgendaSource.disabled(),
        );
      },
    ));

    // 2. Worship Agenda Source
    _entries.add(AgendaSourceEntry(
      id: 'worship',
      domains: {AgendaDomain.prayer, AgendaDomain.mustahab, AgendaDomain.worshipDebt},
      loader: (ctx) async {
        final religionEnabled =
            ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_religion_enabled');
        if (!religionEnabled) {
          return WorshipAgendaSource.disabled(ctx.settingsMap, ctx.db);
        }
        return ctx.guardSource<AgendaSource>(
          'worship',
          () => WorshipAgendaSource.load(ctx.db, ctx.settingsMap, ctx.start, ctx.end),
          () => WorshipAgendaSource.disabled(ctx.settingsMap, ctx.db),
        );
      },
    ));

    // 3. Sports Agenda Source
    _entries.add(AgendaSourceEntry(
      id: 'sports',
      domains: {AgendaDomain.sport},
      loader: (ctx) async {
        final sportsEnabled =
            ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_supplementary_sports_enabled') ||
            ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_sports_enabled');
        if (!sportsEnabled) {
          return SportsAgendaSource.disabled(ctx.db);
        }
        return ctx.guardSource<AgendaSource>(
          'sports',
          () => SportsAgendaSource.load(ctx.db, ctx.settingsMap),
          () => SportsAgendaSource.disabled(ctx.db),
        );
      },
    ));

    // 4. Medicine Agenda Source
    _entries.add(AgendaSourceEntry(
      id: 'medicine',
      domains: {AgendaDomain.medicine},
      loader: (ctx) async {
        final medicineEnabled =
            ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_medicine_enabled');
        if (!medicineEnabled) {
          return MedicineAgendaSource.disabled();
        }
        return ctx.guardSource<AgendaSource>(
          'medicine',
          () => MedicineAgendaSource.load(ctx.db, ctx.settingsMap, ctx.start, ctx.end),
          () => MedicineAgendaSource.disabled(),
        );
      },
    ));

    // 5. Goal Steps Agenda Source
    _entries.add(AgendaSourceEntry(
      id: 'goalSteps',
      domains: {AgendaDomain.goalStep},
      loader: (ctx) async {
        final goalsEnabled =
            ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_goals_enabled');
        if (!goalsEnabled) {
          return GoalStepsAgendaSource.disabled();
        }
        return ctx.guardSource<AgendaSource>(
          'goalSteps',
          () => GoalStepsAgendaSource.load(ctx.db, ctx.start, ctx.end),
          () => GoalStepsAgendaSource.disabled(),
        );
      },
    ));

    // 6. Task Agenda Source
    _entries.add(AgendaSourceEntry(
      id: 'task',
      domains: {AgendaDomain.task},
      loader: (ctx) async {
        final tasksEnabled = ctx.settingsMap['calendar_show_tasks'] != 'false';
        if (!tasksEnabled || !ctx.options.wants(AgendaDomain.task)) {
          return null;
        }
        return ctx.guardSource<AgendaSource?>(
          'task',
          () => TaskAgendaSource.load(
            ctx.db,
            ctx.start,
            ctx.end,
            ctx.todayStr,
            ctx.settingsMap['app_start_date'],
          ),
          () => null,
        );
      },
    ));

    // 7. Course Agenda Source
    _entries.add(AgendaSourceEntry(
      id: 'course',
      domains: {AgendaDomain.course},
      loader: (ctx) async {
        final coursesEnabled =
            ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_courses_enabled');
        if (!coursesEnabled) {
          return CourseAgendaSource.disabled();
        }
        return ctx.guardSource<AgendaSource>(
          'course',
          () => CourseAgendaSource.load(ctx.db, coursesEnabled, ctx.startStr, ctx.endStr),
          () => CourseAgendaSource.disabled(),
        );
      },
    ));

    // 8. Konkur Agenda Source
    _entries.add(AgendaSourceEntry(
      id: 'konkur',
      domains: {AgendaDomain.konkur},
      loader: (ctx) async {
        final konkurEnabled = ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_study_enabled') &&
            ctx.settingsMap['konkur_show_in_dashboard'] != 'false';
        if (!konkurEnabled) {
          return KonkurAgendaSource.disabled();
        }
        return ctx.guardSource<AgendaSource>(
          'konkur',
          () => KonkurAgendaSource.load(konkurEnabled),
          () => KonkurAgendaSource.disabled(),
        );
      },
    ));

    // 9. Cycle Agenda Source
    _entries.add(AgendaSourceEntry(
      id: 'cycle',
      domains: {AgendaDomain.cycle},
      loader: (ctx) async {
        final isFemale = CyclePrivacyGuard.isVisible(ctx.settingsMap);
        final cycleEnabled = ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_cycle_enabled');
        final cycleConsent = ctx.settingsMap['cycle_consent_dashboard'] == 'true';
        final cycleSetupDone = ctx.settingsMap['cycle_setup_done'] == 'true';
        final showCycleInCalendar = ctx.settingsMap['show_cycle_in_calendar'] == 'true';
        final cycleAllowed =
            isFemale && cycleEnabled && cycleConsent && cycleSetupDone && showCycleInCalendar;

        if (!cycleAllowed) {
          return const CycleAgendaSource(cycleOutput: null, cycleAllowed: false);
        }
        return ctx.guardSource<AgendaSource>(
          'cycle',
          () => CycleAgendaSource.load(ctx.db, ctx.settingsMap, cycleAllowed),
          () => const CycleAgendaSource(cycleOutput: null, cycleAllowed: false),
        );
      },
    ));

    // 10. Event Agenda Source (Temporary Events)
    _entries.add(AgendaSourceEntry(
      id: 'event',
      domains: {AgendaDomain.event},
      loader: (ctx) async {
        final routinesEnabled =
            ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_today_routines');
        final eventsEnabled =
            routinesEnabled && ctx.settingsMap['calendar_show_events'] != 'false';
        if (!eventsEnabled || !ctx.options.wants(AgendaDomain.event)) {
          return EventAgendaSource.disabled();
        }
        return ctx.guardSource<AgendaSource>(
          'event',
          () => EventAgendaSource.load(ctx.db, ctx.startStr, ctx.endStr),
          () => EventAgendaSource.disabled(),
        );
      },
    ));

    // 11. Commitment Agenda Source (Planning Commitments & Allocations)
    _entries.add(AgendaSourceEntry(
      id: 'commitment',
      domains: {AgendaDomain.commitment},
      loader: (ctx) async {
        final goalsEnabled =
            ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_goals_enabled');
        final commitmentsEnabled =
            goalsEnabled && ctx.settingsMap['calendar_show_commitments'] != 'false';
        if (!commitmentsEnabled || !ctx.options.wants(AgendaDomain.commitment)) {
          return CommitmentAgendaSource.disabled();
        }
        return ctx.guardSource<AgendaSource>(
          'commitment',
          () => CommitmentAgendaSource.load(ctx.db, ctx.start, ctx.end),
          () => CommitmentAgendaSource.disabled(),
        );
      },
    ));

    // 12. Appointment Agenda Source (Doctor Visits, Vaccinations, Pregnancy Checkups)
    _entries.add(AgendaSourceEntry(
      id: 'appointment',
      domains: {AgendaDomain.appointment},
      loader: (ctx) async {
        final medicineEnabled =
            ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_medicine_enabled');
        final appointmentsEnabled =
            medicineEnabled && ctx.settingsMap['calendar_show_appointments'] != 'false';
        final pregnancyEnabled =
            ModuleGate.instance.isEnabledFrom(ctx.settingsMap, 'module_pregnancy_enabled');

        if (!appointmentsEnabled || !ctx.options.wants(AgendaDomain.appointment)) {
          return AppointmentAgendaSource.disabled();
        }
        return ctx.guardSource<AgendaSource>(
          'appointment',
          () => AppointmentAgendaSource.load(
            db: ctx.db,
            start: ctx.start,
            end: ctx.end,
            pregnancyEnabled: pregnancyEnabled,
          ),
          () => AppointmentAgendaSource.disabled(),
        );
      },
    ));
  }

  /// Loads all registered sources using the provided context.
  Future<Map<String, AgendaSource>> loadSources(AgendaSourceLoadContext ctx) async {
    final result = <String, AgendaSource>{};
    for (final entry in _entries) {
      try {
        final source = await entry.loader(ctx);
        if (source != null) {
          result[entry.id] = source;
        }
      } catch (e, st) {
        RitmoLog.error('AgendaSourceRegistry', 'entry "${entry.id}" threw unexpected error', e, st);
        ctx.failures.add(entry.id);
      }
    }
    return result;
  }

  /// Test seam: register an additional source entry.
  @visibleForTesting
  void register(AgendaSourceEntry entry) {
    _entries.add(entry);
  }

  /// Test seam: replace the entire list of registered sources with custom entries.
  @visibleForTesting
  void setEntries(List<AgendaSourceEntry> entries) {
    _entries.clear();
    _entries.addAll(entries);
  }

  /// Test seam: reset registry back to default built-in sources.
  @visibleForTesting
  void reset() {
    _registerDefaults();
  }
}
