import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_program_calendar.dart';
import 'package:sqflite/sqflite.dart';

/// AgendaSource for the unified Sports & Movement domain.
class SportsAgendaSource {
  SportsAgendaSource({
    required this.prescriptionsByDate,
    required this.legacyPlansByDay,
    required this.sportsEnabled,
  });

  final Map<String, Map<String, dynamic>> prescriptionsByDate;
  final Map<int, List<Map<String, dynamic>>> legacyPlansByDay;
  final bool sportsEnabled;

  static Future<SportsAgendaSource> load(
    Database db,
    Map<String, String> settingsMap,
  ) async {
    final sportsEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_sports_enabled');

    if (!sportsEnabled) {
      return SportsAgendaSource(
        prescriptionsByDate: const {},
        legacyPlansByDay: const {},
        sportsEnabled: false,
      );
    }

    final prescriptionsByDate = <String, Map<String, dynamic>>{};
    final legacyPlansByDay = <int, List<Map<String, dynamic>>>{};

    try {
      final rows = await db.query('ss_session_prescription');
      for (final row in rows) {
        final dateIso = row['dateIso']?.toString();
        if (dateIso != null && dateIso.isNotEmpty) {
          prescriptionsByDate[dateIso] = Map<String, dynamic>.from(row);
        }
      }
    } catch (e, st) {
      debugPrint('[SportsAgendaSource] prescription load error: $e\n$st');
    }

    try {
      final plans = await db.query('ss_workout_plan');
      for (final plan in plans) {
        final day = plan['dayOfWeek'] as int?;
        if (day != null) {
          legacyPlansByDay.putIfAbsent(day, () => []).add(Map<String, dynamic>.from(plan));
        }
      }
    } catch (e, st) {
      debugPrint('[SportsAgendaSource] legacy plan load error: $e\n$st');
    }

    return SportsAgendaSource(
      prescriptionsByDate: prescriptionsByDate,
      legacyPlansByDay: legacyPlansByDay,
      sportsEnabled: sportsEnabled,
    );
  }

  List<AgendaItem> itemsForDate(DateTime date, String dateStr) {
    if (!sportsEnabled) return const [];

    final prescription = prescriptionsByDate[dateStr];
    if (prescription != null) {
      return _itemsForPrescription(prescription, dateStr);
    }

    final legacyDay = SsProgramCalendar.ritmoDayToLegacySsDay(
      SsProgramCalendar.ritmoDayOf(date),
    );
    final plans = legacyPlansByDay[legacyDay] ?? const [];
    return plans.map((plan) => _legacyPlanItem(plan, dateStr)).toList(growable: false);
  }

  List<AgendaItem> _itemsForPrescription(
    Map<String, dynamic> prescription,
    String dateStr,
  ) {
    final slotType = prescription['slotType']?.toString().toUpperCase() ?? 'REST';
    if (slotType == 'REST') return const [];

    final id = prescription['id']?.toString() ?? 'ss_prescription_$dateStr';
    final title = prescription['headlineFa']?.toString().trim().isNotEmpty == true
        ? prescription['headlineFa'].toString()
        : 'تمرین ورزشی';
    final duration = prescription['targetMinutes'] as int? ?? 45;
    final status = prescription['status']?.toString().toUpperCase() ?? 'PLANNED';

    return [
      AgendaItem(
        id: 'sport_${id}_$dateStr',
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
      id: 'sport_${planId}_$dateStr',
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
    final raw = plan['muscleGroups']?.toString();
    if (raw == null || raw.isEmpty) return 'تمرین ورزشی';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.isNotEmpty) {
        return 'تمرین ${decoded.join(' و ')}';
      }
    } catch (_) {
      // Fall through to raw text below.
    }
    return raw.trim().isEmpty ? 'تمرین ورزشی' : raw;
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
