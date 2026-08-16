import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:sqflite/sqflite.dart';

/// منبع اصلی اجندای ماژول حرکت (MovementAgendaSource)
/// تمام جلسات و برنامه‌های حرکتی را با دامنهٔ AgendaDomain.sport و قراردادهای استاندارد منتشر می‌کند.
class MovementAgendaSource implements AgendaSource {
  MovementAgendaSource({
    required this.occurrencesByDate,
    required this.activityKindsById,
    this.isModuleEnabled = true,
  });

  final Map<String, List<MovementOccurrence>> occurrencesByDate;
  final Map<String, MovementActivityKind> activityKindsById;
  final bool isModuleEnabled;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.sport};

  @override
  bool get isEnabled => isModuleEnabled;

  /// منبع غیرفعال/خالی
  static MovementAgendaSource disabled() => MovementAgendaSource(
        occurrencesByDate: const {},
        activityKindsById: const {},
        isModuleEnabled: false,
      );

  /// بارگذاری دسته‌ای داده‌ها برای کل بازهٔ درخواست‌شده از دیتابیس
  static Future<MovementAgendaSource> load(
    Database db,
    Map<String, String> settingsMap, {
    DateTime? start,
    DateTime? end,
  }) async {
    final occurrencesByDate = <String, List<MovementOccurrence>>{};
    final activityKindsById = <String, MovementActivityKind>{};

    try {
      // ۱. بارگذاری تمام نوع فعالیت‌ها
      final kindRows = await db.query(MovementTables.tableActivityKinds);
      for (final row in kindRows) {
        final kind = MovementActivityKind.fromMap(row);
        activityKindsById[kind.id] = kind;
      }

      // ۲. بارگذاری رخدادهای بازه
      String? where;
      List<dynamic>? whereArgs;

      if (start != null && end != null) {
        final startIso = start.toIso8601String().substring(0, 10);
        final endIso = end.toIso8601String().substring(0, 10);
        where = 'dateIso >= ? AND dateIso <= ?';
        whereArgs = [startIso, endIso];
      }

      final occRows = await db.query(
        MovementTables.tableOccurrences,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'dateIso ASC, startTime ASC, createdAt ASC',
      );

      for (final row in occRows) {
        final occ = MovementOccurrence.fromMap(row);
        occurrencesByDate.putIfAbsent(occ.dateIso, () => []).add(occ);
      }
    } catch (_) {
      // در صورت عدم وجود جداول یا خطا، لیست خالی برمی‌گردد
    }

    return MovementAgendaSource(
      occurrencesByDate: occurrencesByDate,
      activityKindsById: activityKindsById,
      isModuleEnabled: true,
    );
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!ctx.options.wants(AgendaDomain.sport) || !isEnabled) {
      return const [];
    }

    final occurrences = occurrencesByDate[ctx.dateStr] ?? const [];
    if (occurrences.isEmpty) return const [];

    final items = <AgendaItem>[];

    for (final occ in occurrences) {
      final kind = activityKindsById[occ.activityKindId];
      final title = kind?.nameFa ?? 'جلسهٔ ورزشی';

      String? subtitle;
      if (occ.goalValue != null && occ.goalValue! > 0) {
        subtitle = 'هدف: ${occ.goalValue} ${occ.goalUnit ?? ""}';
      } else if (occ.startTime != null) {
        subtitle = 'ساعت ${occ.startTime!}';
      }

      final completion = switch (occ.status) {
        MovementOccurrenceStatus.completed => AgendaCompletion.done,
        MovementOccurrenceStatus.partial => AgendaCompletion.partial,
        MovementOccurrenceStatus.skipped => AgendaCompletion.skipped,
        MovementOccurrenceStatus.moved => AgendaCompletion.missed,
        MovementOccurrenceStatus.planned ||
        MovementOccurrenceStatus.inProgress ||
        MovementOccurrenceStatus.late ||
        MovementOccurrenceStatus.restDay =>
          AgendaCompletion.pending,
      };

      final item = AgendaItem(
        id: buildAgendaItemId(AgendaDomain.sport, occ.id, ctx.dateStr),
        sourceId: occ.id,
        domain: AgendaDomain.sport,
        kind: AgendaItemKind.session,
        itemType: occ.startTime != null ? AgendaItemType.fixed : AgendaItemType.flexible,
        title: title,
        subtitle: subtitle,
        dateStr: ctx.dateStr,
        timeOfDay: occ.startTime,
        durationMinutes: occ.goalType == 'duration' ? occ.goalValue?.toInt() : 30,
        category: Category.fitness,
        completion: completion,
        priority: occ.status == MovementOccurrenceStatus.planned ? 2.0 : 1.0,
        isEssential: false,
        deepLink: AgendaDeepLink(
          domain: AgendaDomain.sport,
          targetId: occ.id,
          params: {'occurrenceId': occ.id, 'dateIso': occ.dateIso},
        ),
        meta: {
          'occurrenceId': occ.id,
          'occurrence': occ.toMap(),
          'activityKind': kind?.toMap(),
          'family': kind?.family ?? 'general',
        },
      );

      items.add(item);
    }

    return items;
  }
}
