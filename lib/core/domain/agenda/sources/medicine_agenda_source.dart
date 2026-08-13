import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';

/// AgendaSource for the Medicine domain.
class MedicineAgendaSource implements AgendaSource {
  MedicineAgendaSource({
    required this.medicineLogsByDate,
    required this.medicineEnabled,
  });

  final Map<String, List<Map<String, dynamic>>> medicineLogsByDate;
  final bool medicineEnabled;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.medicine};

  @override
  bool get isEnabled => medicineEnabled;

  static Future<MedicineAgendaSource> load(
    Database db,
    Map<String, String> settingsMap,
    DateTime start,
    DateTime end,
  ) async {
    final medicineEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_medicine_enabled');
    if (!medicineEnabled) {
      return MedicineAgendaSource(medicineLogsByDate: const {}, medicineEnabled: false);
    }

    final medicineLogsByDate = <String, List<Map<String, dynamic>>>{};
    try {
      final startMs = start.millisecondsSinceEpoch;
      final endMs = end.add(const Duration(days: 1)).millisecondsSinceEpoch;
      final logs = await db.rawQuery('''
        SELECT m.*, r.title as medicationName 
        FROM medication_logs m
        LEFT JOIN routines r ON m.routineId = r.id
        WHERE m.scheduledTime >= ? AND m.scheduledTime < ?
      ''', [startMs, endMs]);
      for (final l in logs) {
        final schedTime = l['scheduledTime'] as int?;
        if (schedTime != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(schedTime);
          final dateStr = dt.toIso8601String().substring(0, 10);
          medicineLogsByDate
              .putIfAbsent(dateStr, () => [])
              .add(Map<String, dynamic>.from(l));
        }
      }
    } catch (e, st) {
      debugPrint('[MedicineAgendaSource] Load error: $e\n$st');
    }

    return MedicineAgendaSource(
      medicineLogsByDate: medicineLogsByDate,
      medicineEnabled: medicineEnabled,
    );
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!ctx.options.wants(AgendaDomain.medicine)) return const [];
    if (!medicineEnabled) return const [];

    final logs = medicineLogsByDate[ctx.dateStr] ?? const [];
    if (logs.isEmpty) return const [];

    final items = <AgendaItem>[];
    for (final log in logs) {
      final id = log['id']?.toString() ?? 'med_${ctx.dateStr}';
      // MED-02: ActionRouter forwards `sourceId` to CompletionGateway as the
      // medication identity, and the gateway writes it into
      // medication_logs.routineId. Publishing the log row id here made every
      // completion target a routine that does not exist, so the write was lost.
      // The join already carries m.routineId, so use that as the identity and
      // keep the log row id in meta for callers that need the specific dose.
      final routineId = log['routineId']?.toString();
      final targetId = routineId ?? id;
      final title = log['medicationName'] as String? ?? 'یادآور دارو';
      
      String? timeOfDay;
      final schedTime = log['scheduledTime'] as int?;
      if (schedTime != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(schedTime);
        timeOfDay = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      
      final status = log['status'] as String?;
      final isDone = status == 'TAKEN'; // NOT defaulting to TAKEN anymore!

      items.add(AgendaItem(
        id: buildAgendaItemId(AgendaDomain.medicine, id, ctx.dateStr),
        sourceId: targetId,
        domain: AgendaDomain.medicine,
        itemType: AgendaItemType.fixed,
        title: title,
        subtitle: log['note'] as String?,
        dateStr: ctx.dateStr,
        timeOfDay: timeOfDay,
        durationMinutes: 5,
        category: Category.medical,
        priority: 2.0,
        isEssential: true,
        deepLink: AgendaDeepLink(domain: AgendaDomain.medicine, targetId: targetId),
        completion: isDone ? AgendaCompletion.done : AgendaCompletion.pending,
        meta: {
          'medicationLog': log,
          'medicationLogId': id,
          'routineId': routineId,
        },
      ));
    }

    return items;
  }
}
