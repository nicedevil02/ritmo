import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:sqflite/sqflite.dart';

class CycleAgendaSource implements AgendaSource {
  final CycleEngineOutput? cycleOutput;
  final bool cycleAllowed;

  const CycleAgendaSource({
    required this.cycleOutput,
    required this.cycleAllowed,
  });

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.cycle};

  @override
  bool get isEnabled => cycleAllowed;

  static Future<CycleAgendaSource> load(
    Database db,
    Map<String, String> settingsMap,
    bool cycleAllowed,
  ) async {
    CycleEngineOutput? cycleOutput;

    if (cycleAllowed) {
      try {
        cycleOutput = await CycleEngine().calculate(CycleEngineInput(
          db: db,
          appSettings: settingsMap,
          now: DateTime.now(),
        ));
      } catch (e) {
        debugPrint('CycleAgendaSource cycle calc error: $e');
      }
    }

    return CycleAgendaSource(
      cycleOutput: cycleOutput,
      cycleAllowed: cycleAllowed,
    );
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!ctx.options.wants(AgendaDomain.cycle)) return const [];

    final out = cycleOutput;
    if (out == null || !out.hasData) return const [];

    final date = ctx.date;
    final day = DateTime(date.year, date.month, date.day);

    bool inWindow(DateTime? start, DateTime? end) {
      if (start == null || end == null) return false;
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day);
      return !day.isBefore(s) && !day.isAfter(e);
    }

    String? title;
    if (ctx.isToday && out.dayOfPeriod > 0) {
      title = 'چرخه ماهانه (روز ${out.dayOfPeriod})';
    } else if (inWindow(out.nextPeriodWindowStart, out.nextPeriodWindowEnd)) {
      title = 'پیش‌بینی شروع دوره';
    } else if (inWindow(out.pmsWindowStart, out.pmsWindowEnd)) {
      title = 'پنجره‌ی PMS';
    } else if (inWindow(out.fertileWindowStart, out.fertileWindowEnd)) {
      title = 'پنجره‌ی باروری';
    }

    if (title == null) return const [];

    final item = AgendaItem(
      id: buildAgendaItemId(AgendaDomain.cycle, ctx.dateStr, ctx.dateStr),
      domain: AgendaDomain.cycle,
      sourceId: ctx.dateStr,
      title: title,
      dateStr: ctx.dateStr,
      category: Category.personal,
      priority: 0.8,
      deepLink: AgendaDeepLink(domain: AgendaDomain.cycle, targetId: ctx.dateStr),
    );
    
    return [item];
  }
}
