// lib/features/supplementary_sports/domain/ss_agenda_source.dart

import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_week_resolver.dart';
import 'package:sqflite/sqflite.dart';

/// AgendaSource for the Supplementary Sports & Movement domain.
class SsAgendaSource {
  SsAgendaSource({
    required this.movementRoutines,
    required this.sportsEnabled,
    this.prescriptionsByDate = const {},
    required this.programStartDate,
    required this.totalWeeks,
    required this.db,
    required this.hasWeekCol,
  });

  final List<Map<String, dynamic>> movementRoutines;
  final bool sportsEnabled;
  final Map<String, Map<String, dynamic>> prescriptionsByDate;
  final DateTime programStartDate;
  final int totalWeeks;
  final Database db;
  final bool hasWeekCol;

  static Future<SsAgendaSource> load(
    Database db,
    Map<String, String> settingsMap,
  ) async {
    final sportsEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_sports_enabled') ||
        ModuleGate.instance.isEnabledFrom(settingsMap, 'module_supplementary_sports_enabled');

    if (!sportsEnabled) {
      return SsAgendaSource(
        movementRoutines: const [],
        sportsEnabled: false,
        programStartDate: DateTime.now(),
        totalWeeks: 4,
        db: db,
        hasWeekCol: false,
      );
    }

    DateTime pStart = DateTime.now();
    int totalW = 4;

    bool hasWeekCol = false;
    try {
      pStart = await SsWeekResolver.resolveProgramStartDate(db);
      totalW = await SsWeekResolver.resolveTotalWeeks(db);

      final tableInfo = await db.rawQuery("PRAGMA table_info(ss_workout_plan)");
      hasWeekCol = tableInfo.any((col) => col['name'] == 'week');
    } catch (e) {
      debugPrint('[SsAgendaSource] Schema load error: $e');
    }

    // 2. New ss_session_prescription (keyed by dateIso)
    final prescriptionsByDate = <String, Map<String, dynamic>>{};
    try {
      final rows = await db.query('ss_session_prescription');
      for (final r in rows) {
        final dateIso = r['dateIso'] as String?;
        if (dateIso != null) {
          prescriptionsByDate[dateIso] = Map<String, dynamic>.from(r);
        }
      }
    } catch (_) {}

    // 3. Movement routines
    final movementRoutines = <Map<String, dynamic>>[];
    try {
      final rRows = await db.query(
        'routines',
        where: "category = 'fitness' AND isArchived = 0",
      );
      for (final r in rRows) {
        movementRoutines.add(Map<String, dynamic>.from(r));
      }
    } catch (_) {}

    return SsAgendaSource(
      movementRoutines: movementRoutines,
      sportsEnabled: sportsEnabled,
      prescriptionsByDate: prescriptionsByDate,
      programStartDate: pStart,
      totalWeeks: totalW,
      db: db,
      hasWeekCol: hasWeekCol,
    );
  }

  Future<List<AgendaItem>> itemsForDate(DateTime date, String dateStr) async {
    if (!sportsEnabled) return const [];

    final items = <AgendaItem>[];

    // 1. Prescription-based items (new system takes priority)
    final pres = prescriptionsByDate[dateStr];
    if (pres != null) {
      final presId = pres['id'] as String? ?? 'pres_$dateStr';
      final slotType = pres['slotType'] as String? ?? 'STRENGTH';
      final status = pres['status'] as String? ?? 'PLANNED';
      final headline = pres['headlineFa'] as String? ?? 'تمرین ورزشی';
      final targetMinutes = pres['targetMinutes'] as int? ?? 45;
      final coachNote = pres['coachNoteFa'] as String?;

      if (status == 'MOVED') {
        // Return only movement routines if prescription is moved
        items.addAll(_movementItems(dateStr));
        final seenMove = <String>{};
        return items.where((i) => seenMove.add('${i.domain.name}_${i.sourceId}_${i.dateStr}_${i.title}')).toList();
      }

      // Skip REST days — nothing on agenda
      if (slotType != 'REST') {
        final completion = switch (status) {
          'DONE' => AgendaCompletion.done,
          'PARTIAL' => AgendaCompletion.partial,
          'SKIPPED' => AgendaCompletion.skipped,
          _ => AgendaCompletion.pending,
        };

        items.add(AgendaItem(
          id: 'sport:pres:$presId:$dateStr',
          sourceId: presId,
          domain: AgendaDomain.sport,
          itemType: AgendaItemType.flexible,
          title: headline,
          subtitle: coachNote,
          dateStr: dateStr,
          durationMinutes: targetMinutes,
          category: Category.fitness,
          deepLink: AgendaDeepLink(domain: AgendaDomain.sport, targetId: presId),
          completion: completion,
          meta: {'prescription': pres},
        ));
      }

      // When prescriptions exist, skip legacy plans for this date
      final res = [...items, ..._movementItems(dateStr)];
      final seen = <String>{};
      return res.where((i) => seen.add('${i.domain.name}_${i.sourceId}_${i.dateStr}_${i.title}')).toList();
    }

    // 2. Legacy ss_workout_plan fallback
    final dayOfWeek = date.weekday;
    final activeW = SsWeekResolver.resolveActiveWeek(
      programStartDate: programStartDate,
      targetDate: date,
      totalWeeks: totalWeeks,
    );

    List<Map<String, dynamic>> filteredPlans;
    if (hasWeekCol) {
      filteredPlans = await db.query(
        'ss_workout_plan',
        where: 'dayOfWeek = ? AND week = ?',
        whereArgs: [dayOfWeek, activeW],
      );
    } else {
      debugPrint('[SsAgendaSource] warning: week column not found in ss_workout_plan');
      filteredPlans = await db.query(
        'ss_workout_plan',
        where: 'dayOfWeek = ?',
        whereArgs: [dayOfWeek],
      );
    }

    for (final plan in filteredPlans) {
      final planId = plan['id']?.toString() ?? 'plan_$dayOfWeek';
      final title = SsWeekResolver.formatSportTitle(plan);
      final timeOfDay =
          plan['timeOfDay'] as String? ?? plan['targetTime'] as String?;
      final duration = plan['durationMinutes'] as int? ?? 45;

      items.add(AgendaItem(
        id: 'sport:plan:$planId:$dateStr',
        sourceId: planId,
        domain: AgendaDomain.sport,
        itemType: AgendaItemType.flexible,
        title: title,
        dateStr: dateStr,
        timeOfDay: timeOfDay,
        durationMinutes: duration,
        category: Category.fitness,
        deepLink: AgendaDeepLink(domain: AgendaDomain.sport, targetId: planId),
        completion: AgendaCompletion.pending,
        meta: {'workoutPlan': plan},
      ));
    }

    // 3. Movement routines
    items.addAll(_movementItems(dateStr));

    // Step 4: Final Deduplication Guard
    final seen = <String>{};
    return items.where((i) => seen.add('${i.domain.name}_${i.sourceId}_${i.dateStr}_${i.title}')).toList();
  }

  List<AgendaItem> _movementItems(String dateStr) {
    final items = <AgendaItem>[];
    for (final r in movementRoutines) {
      final rId = r['id'] as String;
      final title = r['title'] as String? ?? 'فعالیت حرکتی';
      final isMeetup = (r['movementIsMeetup'] as int? ?? 0) == 1;
      final duration = r['targetDurationMinutes'] as int? ?? 30;

      items.add(AgendaItem(
        id: 'sport:movement:$rId:$dateStr',
        sourceId: rId,
        domain: AgendaDomain.sport,
        itemType: isMeetup ? AgendaItemType.fixed : AgendaItemType.flexible,
        title: title,
        dateStr: dateStr,
        durationMinutes: duration,
        category: Category.fitness,
        deepLink: AgendaDeepLink(domain: AgendaDomain.sport, targetId: rId),
        completion: AgendaCompletion.pending,
        meta: {'routine': r},
      ));
    }
    return items;
  }
}

typedef SportsAgendaSource = SsAgendaSource;
