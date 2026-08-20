import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_program_calendar.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_week_resolver.dart';
import 'package:sqflite/sqflite.dart';

/// AgendaSource for the unified Sports & Movement domain.
class SportsAgendaSource implements AgendaSource {
  SportsAgendaSource({
    required this.prescriptionsByDate,
    required this.sportsEnabled,
    required this.programStartDate,
    required this.totalWeeks,
    required this.db,
    required this.hasWeekCol,
    required this.legacyPlans,
  });

  final Map<String, Map<String, dynamic>> prescriptionsByDate;
  final bool sportsEnabled;
  final DateTime programStartDate;
  final int totalWeeks;
  final Database db;
  final bool hasWeekCol;
  final List<Map<String, dynamic>> legacyPlans;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.sport};

  @override
  bool get isEnabled => sportsEnabled;

  /// Returns an empty, disabled source (fallback when module is off or load fails).
  static SportsAgendaSource disabled(Database db) => SportsAgendaSource(
    prescriptionsByDate: const {},
    sportsEnabled: false,
    programStartDate: DateTime(2000),
    totalWeeks: 4,
    db: db,
    hasWeekCol: false,
    legacyPlans: const [],
  );

  static Future<SportsAgendaSource> load(
    Database db,
    Map<String, String> settingsMap,
  ) async {
    final sportsEnabled =
        ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_sports_enabled',
        ) ||
        ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_supplementary_sports_enabled',
        );

    if (!sportsEnabled) {
      return SportsAgendaSource(
        prescriptionsByDate: const {},
        sportsEnabled: false,
        programStartDate: DateTime.now(),
        totalWeeks: 4,
        db: db,
        hasWeekCol: false,
        legacyPlans: const [],
      );
    }

    final prescriptionsByDate = <String, Map<String, dynamic>>{};
    DateTime pStart = DateTime.now();
    int totalW = 4;

    try {
      final rows = await db.query('ss_session_prescription');
      for (final row in rows) {
        final dateIso = row['dateIso']?.toString();
        if (dateIso != null && dateIso.isNotEmpty) {
          prescriptionsByDate[dateIso] = Map<String, dynamic>.from(row);
        }
      }
    } catch (e, st) {
      RitmoLog.error('SportsAgendaSource', 'prescription load failed', e, st);
    }

    bool hasWeekCol = false;
    try {
      pStart = await SsWeekResolver.resolveProgramStartDate(db);
      totalW = await SsWeekResolver.resolveTotalWeeks(db);

      final tableInfo = await db.rawQuery("PRAGMA table_info(ss_workout_plan)");
      hasWeekCol = tableInfo.any((col) => col['name'] == 'week');
    } catch (e, st) {
      RitmoLog.error('SportsAgendaSource', 'schema load failed', e, st);
    }

    final legacyPlans = <Map<String, dynamic>>[];
    try {
      final pRows = await db.query('ss_workout_plan');
      for (final r in pRows) {
        legacyPlans.add(Map<String, dynamic>.from(r));
      }
    } catch (e, st) {
      RitmoLog.error(
        'SportsAgendaSource',
        'schema load ss_workout_plan failed',
        e,
        st,
      );
    }

    return SportsAgendaSource(
      prescriptionsByDate: prescriptionsByDate,
      sportsEnabled: sportsEnabled,
      programStartDate: pStart,
      totalWeeks: totalW,
      db: db,
      hasWeekCol: hasWeekCol,
      legacyPlans: legacyPlans,
    );
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!ctx.options.wants(AgendaDomain.sport)) return const [];
    if (!sportsEnabled) return const [];

    final dateStr = ctx.dateStr;
    final date = ctx.date;

    final prescription = prescriptionsByDate[dateStr];
    if (prescription != null) {
      return _itemsForPrescription(prescription, dateStr);
    }

    final legacyDay = SsProgramCalendar.ritmoDayToLegacySsDay(
      SsProgramCalendar.ritmoDayOf(date),
    );
    final activeW = SsWeekResolver.resolveActiveWeek(
      programStartDate: programStartDate,
      targetDate: date,
      totalWeeks: totalWeeks,
    );

    List<Map<String, dynamic>> filteredPlans;
    if (hasWeekCol) {
      filteredPlans = legacyPlans
          .where((p) => p['dayOfWeek'] == legacyDay && p['week'] == activeW)
          .toList();
    } else {
      filteredPlans = legacyPlans
          .where((p) => p['dayOfWeek'] == legacyDay)
          .toList();
    }

    final items = filteredPlans
        .map((plan) => _legacyPlanItem(plan, dateStr))
        .toList(growable: false);

    // Step 4: Final Deduplication Guard
    final seen = <String>{};
    return items
        .where(
          (i) => seen.add(
            '${i.domain.name}_${i.sourceId}_${i.dateStr}_${i.title}',
          ),
        )
        .toList();
  }

  List<AgendaItem> _itemsForPrescription(
    Map<String, dynamic> prescription,
    String dateStr,
  ) {
    final slotType =
        prescription['slotType']?.toString().toUpperCase() ?? 'REST';
    if (slotType == 'REST') return const [];

    final id = prescription['id']?.toString() ?? 'ss_prescription_$dateStr';
    final title =
        prescription['headlineFa']?.toString().trim().isNotEmpty == true
        ? prescription['headlineFa'].toString()
        : 'تمرین ورزشی';
    final duration = prescription['targetMinutes'] as int? ?? 45;
    final status =
        prescription['status']?.toString().toUpperCase() ?? 'PLANNED';

    return [
      AgendaItem(
        id: buildAgendaItemId(AgendaDomain.sport, id, dateStr),
        sourceId: id,
        domain: AgendaDomain.sport,
        itemType: AgendaItemType.flexible,
        title: title,
        subtitle: prescription['coachNoteFa'] as String?,
        dateStr: dateStr,
        durationMinutes: duration,
        category: Category.fitness,
        deepLink: AgendaDeepLink(domain: AgendaDomain.sport, targetId: id),
        completion: _completionFor(status),
        meta: {'prescription': prescription},
      ),
    ];
  }

  AgendaItem _legacyPlanItem(Map<String, dynamic> plan, String dateStr) {
    final planId = plan['id']?.toString() ?? 'unknown_plan';
    final title = _legacyTitle(plan);
    final duration = plan['estimatedMinutes'] as int? ?? 45;

    return AgendaItem(
      id: buildAgendaItemId(AgendaDomain.sport, planId, dateStr),
      sourceId: planId,
      domain: AgendaDomain.sport,
      itemType: AgendaItemType.flexible,
      title: title,
      dateStr: dateStr,
      durationMinutes: duration,
      category: Category.fitness,
      deepLink: AgendaDeepLink(domain: AgendaDomain.sport, targetId: planId),
      completion: AgendaCompletion.pending,
      meta: {'legacyWorkoutPlan': plan},
    );
  }

  String _legacyTitle(Map<String, dynamic> plan) {
    return SsWeekResolver.formatSportTitle(plan);
  }

  AgendaCompletion _completionFor(String status) {
    return switch (status) {
      'DONE' => AgendaCompletion.done,
      'PARTIAL' => AgendaCompletion.partial,
      'SKIPPED' => AgendaCompletion.skipped,
      'MOVED' => AgendaCompletion.none,
      _ => AgendaCompletion.pending,
    };
  }
}
