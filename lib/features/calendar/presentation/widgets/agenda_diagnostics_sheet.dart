import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_source_registry.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/routine_agenda_source.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/date_key.dart';

/// Walks every layer between the database and the calendar agenda and reports
/// where items are lost with full per-source observability.
Future<String> collectAgendaDiagnostics({DateTime? targetDate}) async {
  final out = StringBuffer();
  final now = targetDate ?? DateTime.now();

  final todayStr = DateKey.of(now);
  final endStr = DateKey.of(DateKey.addDays(now, 30));

  // Verdict inputs (-1 = step never produced a value).
  var dbRoutines = -1;
  var dbSchedules = -1;
  var dbOccToday = -1;
  var srcActive = -1;
  var srcItems = -1;
  var svcDayItems = -1;
  var svcRangeItems = -1;

  out.writeln('=== RITMO AGENDA DIAGNOSTICS ===');
  out.writeln('targetDate=$todayStr');
  out.writeln('range=$todayStr..$endStr');
  out.writeln('');

  try {
    final db = await DatabaseHelper.instance.database;

    Future<int> countOf(String sql, [List<Object?>? args]) async {
      final rows = await db.rawQuery(sql, args);
      if (rows.isEmpty) return -1;
      final value = rows.first.values.first;
      return value is num ? value.toInt() : -1;
    }

    // ---- 1. settings ------------------------------------------------------
    var settingsMap = <String, String>{};
    try {
      final settings = await db.query('app_settings');
      settingsMap = {
        for (final s in settings)
          if (s['key'] != null) s['key'].toString(): s['value']?.toString() ?? ''
      };
      out.writeln('-- settings (${settings.length} rows)');
    } catch (e) {
      out.writeln('-- settings FAILED: $e');
    }

    out.writeln('app_start_date = ${settingsMap['app_start_date'] ?? '(unset)'}');
    out.writeln('onboarding_completed = ${settingsMap['onboarding_completed'] ?? '(unset)'}');
    out.writeln(
      'module_today_routines = ${settingsMap['module_today_routines'] ?? '(unset)'} '
      '=> gate=${ModuleGate.instance.isEnabledFrom(settingsMap, 'module_today_routines')}',
    );
    out.writeln('calendar_show_tasks = ${settingsMap['calendar_show_tasks'] ?? '(unset)'}');
    out.writeln('calendar_show_events = ${settingsMap['calendar_show_events'] ?? '(unset)'}');
    out.writeln('calendar_show_worship_obligatory = ${settingsMap['calendar_show_worship_obligatory'] ?? '(unset)'}');
    out.writeln('calendar_show_worship_mustahab = ${settingsMap['calendar_show_worship_mustahab'] ?? '(unset)'}');
    out.writeln('');

    // ---- 2. raw database --------------------------------------------------
    out.writeln('-- database');
    try {
      final total = await countOf('SELECT COUNT(*) FROM routines');
      dbRoutines = await countOf('SELECT COUNT(*) FROM routines WHERE isArchived = 0');
      out.writeln('routines total=$total notArchived=$dbRoutines');
    } catch (e) {
      out.writeln('routines FAILED: $e');
    }
    try {
      dbSchedules = await countOf('SELECT COUNT(*) FROM routine_schedules');
      out.writeln('routine_schedules=$dbSchedules');
    } catch (e) {
      out.writeln('routine_schedules FAILED: $e');
    }
    try {
      final occTotal = await countOf('SELECT COUNT(*) FROM routine_occurrences');
      dbOccToday = await countOf(
        'SELECT COUNT(*) FROM routine_occurrences WHERE date = ?',
        [todayStr],
      );
      final occRange = await countOf(
        'SELECT COUNT(*) FROM routine_occurrences WHERE date >= ? AND date <= ?',
        [todayStr, endStr],
      );
      out.writeln('routine_occurrences total=$occTotal today=$dbOccToday range=$occRange');
      final firstDate = await db.rawQuery(
        'SELECT MIN(date) a, MAX(date) b FROM routine_occurrences',
      );
      if (firstDate.isNotEmpty) {
        out.writeln('occurrence dates: ${firstDate.first['a']} .. ${firstDate.first['b']}');
      }
    } catch (e) {
      out.writeln('routine_occurrences FAILED: $e');
    }
    try {
      out.writeln('simple_tasks=${await countOf('SELECT COUNT(*) FROM simple_tasks')}');
      out.writeln('temporary_events=${await countOf('SELECT COUNT(*) FROM temporary_events')}');
      out.writeln('routine_completions=${await countOf('SELECT COUNT(*) FROM routine_completions')}');
      out.writeln('worship_day_exceptions=${await countOf('SELECT COUNT(*) FROM worship_day_exceptions')}');
    } catch (e) {
      out.writeln('tables count FAILED: $e');
    }
    out.writeln('');

    // ---- 3. per-source metrics & observability -----------------------------
    out.writeln('-- Per-Source Agenda Metrics (${AgendaSourceRegistry.instance.entries.length} registered sources)');
    final failures = <String>[];
    final loadCtx = AgendaSourceLoadContext(
      db: db,
      settingsMap: settingsMap,
      start: now,
      end: now,
      startStr: todayStr,
      endStr: todayStr,
      todayStr: todayStr,
      options: const AgendaQueryOptions(),
      failures: failures,
    );

    final dayCtx = AgendaDayContext(
      date: now,
      dateStr: todayStr,
      isToday: true,
      prayerTimes: const {},
      options: const AgendaQueryOptions(),
    );

    var loadedSourceCount = 0;
    var totalSourceItems = 0;

    for (final entry in AgendaSourceRegistry.instance.entries) {
      try {
        final source = await entry.loader(loadCtx);
        if (source == null) {
          out.writeln('  [DISABLED] ${entry.id.padRight(14)} domains=${entry.domains.map((d) => d.name).join(',')}');
          continue;
        }
        loadedSourceCount++;
        final items = source.itemsForDate(dayCtx);
        totalSourceItems += items.length;
        out.writeln(
          '  [OK]       ${entry.id.padRight(14)} items=${items.length} '
          'domains=${entry.domains.map((d) => d.name).join(',')}',
        );
        for (final it in items.take(2)) {
          out.writeln('       * ${it.title} [${it.domain.name} / ${it.kind.name}] @ ${it.timeOfDay ?? 'floating'}');
        }
      } catch (e) {
        failures.add(entry.id);
        out.writeln('  [FAILED]   ${entry.id.padRight(14)} error=$e');
      }
    }
    out.writeln('sources loaded: $loadedSourceCount, failed: ${failures.length}, totalItems: $totalSourceItems');
    out.writeln('');

    // ---- 4. routine source specific trace ---------------------------------
    out.writeln('-- RoutineAgendaSource Detailed Trace');
    try {
      final source = await RoutineAgendaSource.load(db, settingsMap, todayStr, endStr);
      final active = source.activeForDate(now);
      srcActive = active.length;
      final items = source.itemsForDate(dayCtx);
      srcItems = items.length;
      out.writeln('activeForDate(today)=$srcActive, itemsForDate(today)=$srcItems');

      for (final r in source.routines.take(5)) {
        final id = r['id']?.toString() ?? '?';
        final sched = source.schedules.firstWhere(
          (s) => (s['routineId'] ?? s['routine_id'])?.toString() == id,
          orElse: () => <String, dynamic>{},
        );
        final hasOcc = source.occurrences.any((o) {
          final oid = (o['routine_id'] ?? o['routineId'])?.toString();
          final od = o['date']?.toString();
          return oid == id && od != null && od.length >= 10 && od.substring(0, 10) == todayStr;
        });
        final isActive = active.any((a) =>
            ((a['routine'] as Map<String, dynamic>?)?['id'])?.toString() == id);
        out.writeln(
          '  - $id type=${r['itemType'] ?? '-'} archived=${r['isArchived'] ?? '-'} '
          'sched=${sched.isEmpty ? 'NONE' : (sched['daysOfWeek'] ?? 'set')} '
          'rule=${sched['recurrenceRule'] == null ? 'null' : 'set'} '
          'occToday=$hasOcc active=$isActive',
        );
      }
    } catch (e, st) {
      out.writeln('RoutineAgendaSource trace FAILED: $e');
      out.writeln('$st'.split('\n').take(3).join('\n'));
    }
    out.writeln('');

    // ---- 5. full service pipeline ----------------------------------------
    out.writeln('-- DayAgendaService Pipeline');
    try {
      DayAgendaService.instance.invalidateAll();
      final day = await DayAgendaService.instance.agendaForDate(now);
      svcDayItems = day.items.length;
      out.writeln('agendaForDate(today)=$svcDayItems');
      final domainCounts = <String, int>{};
      for (final item in day.items) {
        domainCounts[item.domain.name] = (domainCounts[item.domain.name] ?? 0) + 1;
      }
      if (domainCounts.isNotEmpty) out.writeln('by domain: $domainCounts');

      final range = await DayAgendaService.instance.agendaForRange(
        now,
        DateKey.addDays(now, 7),
      );
      var total = 0;
      for (final agenda in range.values) {
        total += agenda.items.length;
      }
      svcRangeItems = total;
      out.writeln('agendaForRange(today..+7) days=${range.length} items=$total');

      final status = DayAgendaService.instance.lastLoadStatus;
      out.writeln(
        'lastLoadStatus fatal=${status.fatal} '
        'failed=${status.failedSources.isEmpty ? 'none' : status.failedSources.join(',')} '
        'degraded=${status.isDegraded}',
      );
    } catch (e, st) {
      out.writeln('DayAgendaService FAILED: $e');
      out.writeln('$st'.split('\n').take(3).join('\n'));
    }
  } catch (e, st) {
    out.writeln('FATAL: $e');
    out.writeln('$st'.split('\n').take(5).join('\n'));
  }

  // ---- verdict ------------------------------------------------------------
  out.writeln('');
  out.writeln('== VERDICT ==');
  if (dbRoutines == 0) {
    out.writeln('DATA LAYER: no routines in the database at all.');
  } else if (dbSchedules == 0 && dbOccToday == 0) {
    out.writeln('DATA LAYER: routines exist but have neither schedules nor occurrences.');
  } else if (srcActive == 0) {
    out.writeln('RESOLUTION LAYER: activeForDate(today) is empty -> recurrence rule / occurrence matching.');
  } else if (srcItems == 0) {
    out.writeln('MAPPING LAYER: routines are active but itemsForDate returns nothing -> domain/medicine filter.');
  } else if (svcDayItems == 0 || svcRangeItems == 0) {
    out.writeln('SERVICE LAYER: source produces items but DayAgendaService drops them -> module gates / app_start_date / context.');
  } else {
    out.writeln('UI LAYER: the service returns items ($svcRangeItems in 8 days), so the calendar view is not rendering them.');
  }

  return out.toString();
}

/// Bottom sheet that renders [collectAgendaDiagnostics] with copy + retry.
class AgendaDiagnosticsSheet extends StatefulWidget {
  const AgendaDiagnosticsSheet({super.key, this.onRetry});

  final VoidCallback? onRetry;

  static Future<void> show(BuildContext context, {VoidCallback? onRetry}) {
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
      ),
      builder: (ctx) => AgendaDiagnosticsSheet(onRetry: onRetry),
    );
  }

  @override
  State<AgendaDiagnosticsSheet> createState() => _AgendaDiagnosticsSheetState();
}

class _AgendaDiagnosticsSheetState extends State<AgendaDiagnosticsSheet> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = collectAgendaDiagnostics();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(RitmoSpacing.lg),
          child: FutureBuilder<String>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final report = snap.hasError
                  ? 'diagnostics crashed: ${snap.error}'
                  : (snap.data ?? '');

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bug_report_outlined, size: 20, color: colors.textPrimary),
                      const SizedBox(width: RitmoSpacing.sm),
                      Expanded(
                        child: Text(
                          'تشخیص خالی‌بودن برنامه',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'کپی گزارش',
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: report));
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('گزارش کپی شد')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: RitmoSpacing.sm),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(RitmoSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.textPrimary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(RitmoRadius.card),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: SelectableText(
                            report,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              fontFamily: 'monospace',
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: RitmoSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _future = collectAgendaDiagnostics();
                          }),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('اجرای مجدد'),
                        ),
                      ),
                      const SizedBox(width: RitmoSpacing.sm),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            DayAgendaService.instance.invalidateAll();
                            Navigator.of(ctx).pop();
                            widget.onRetry?.call();
                          },
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: const Text('پاک‌سازی و بازخوانی'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
