import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite/sqflite.dart';

class CycleAgendaSource implements AgendaSource {
  final CycleEngineOutput? cycleOutput;
  final bool cycleAllowed;
  final List<Map<String, dynamic>> periodRows;
  final bool isPregnancy;

  const CycleAgendaSource({
    required this.cycleOutput,
    required this.cycleAllowed,
    this.periodRows = const [],
    this.isPregnancy = false,
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
    final isFemale = CyclePrivacyGuard.isVisible(settingsMap);
    final isCycleEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_cycle_enabled',
    );
    final calendarConsent =
        settingsMap['show_cycle_in_calendar'] == 'true' ||
        settingsMap['cycle_consent_calendar'] == 'true';
    final effectiveAllowed =
        isFemale && isCycleEnabled && calendarConsent && cycleAllowed;
    final isPregnant = CycleSettings.isPregnancyMode(settingsMap);

    if (!effectiveAllowed) {
      return const CycleAgendaSource(
        cycleOutput: null,
        cycleAllowed: false,
        periodRows: [],
        isPregnancy: false,
      );
    }

    CycleEngineOutput? cycleOutput;
    List<Map<String, dynamic>> periodRows = const [];

    try {
      periodRows = await db.query('cycle_periods', orderBy: 'startDate ASC');

      try {
        cycleOutput = await RitmoEngineBus.instance
            .execute<CycleEngineInput, CycleEngineOutput>(
              CycleEngine,
              CycleEngineInput(
                db: db,
                appSettings: settingsMap,
                now: DateTime.now(),
              ),
            );
      } catch (e) {
        RitmoLog.debug('CycleAgendaSource', 'Bus execute failed, falling back to direct calculation: $e');
        cycleOutput = await CycleEngine().calculate(
          CycleEngineInput(
            db: db,
            appSettings: settingsMap,
            now: DateTime.now(),
          ),
        );
      }
    } catch (e, st) {
      RitmoLog.error(
        'CycleAgendaSource',
        'error during load',
        e,
        st,
      );
    }

    return CycleAgendaSource(
      cycleOutput: cycleOutput,
      cycleAllowed: effectiveAllowed,
      periodRows: periodRows,
      isPregnancy: isPregnant,
    );
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!ctx.options.wants(AgendaDomain.cycle) || !isEnabled || isPregnancy) {
      return const [];
    }

    final date = ctx.date;
    final day = CycleDateContract.cleanDate(date);
    final items = <AgendaItem>[];

    // 1. Check actual recorded/past periods from cycle_periods (روزهای قاعدگی)
    for (final row in periodRows) {
      final start = CycleDateContract.parseDayKey(row['startDate']?.toString());
      if (start == null) continue;

      final end = CycleDateContract.parseDayKey(row['endDate']?.toString());
      if (end != null) {
        if (CycleDateContract.inWindow(day, start, end)) {
          final dayNum = CycleDateContract.daysBetween(start, day) + 1;
          items.add(
            AgendaItem(
              id: buildAgendaItemId(
                AgendaDomain.cycle,
                '${ctx.dateStr}_actual',
                ctx.dateStr,
              ),
              domain: AgendaDomain.cycle,
              sourceId: '${ctx.dateStr}_actual',
              title: 'دوره قاعدگی (روز ${toPersianDigits(dayNum)})',
              dateStr: ctx.dateStr,
              category: Category.personal,
              priority: 0.85,
              deepLink: AgendaDeepLink(
                domain: AgendaDomain.cycle,
                targetId: ctx.dateStr,
              ),
            ),
          );
          break;
        }
      } else {
        // Open ongoing period
        final daysDiff = CycleDateContract.daysBetween(start, day);
        if (daysDiff >= 0 && daysDiff <= 10) {
          final dayNum = daysDiff + 1;
          items.add(
            AgendaItem(
              id: buildAgendaItemId(
                AgendaDomain.cycle,
                '${ctx.dateStr}_actual_open',
                ctx.dateStr,
              ),
              domain: AgendaDomain.cycle,
              sourceId: '${ctx.dateStr}_actual_open',
              title: 'دوره قاعدگی (روز ${toPersianDigits(dayNum)})',
              dateStr: ctx.dateStr,
              category: Category.personal,
              priority: 0.85,
              deepLink: AgendaDeepLink(
                domain: AgendaDomain.cycle,
                targetId: ctx.dateStr,
              ),
            ),
          );
          break;
        }
      }
    }

    // 2. Future prediction items (پیش‌بینی قاعدگی بعدی و PMS — بدون پنجره باروری)
    final out = cycleOutput;
    if (out != null &&
        out.hasData &&
        out.currentPhase != CyclePhase.pregnancy) {
      bool inFutureWindow(DateTime? start, DateTime? end) {
        if (start == null || end == null) return false;
        final s = CycleDateContract.cleanDate(start);
        final e = CycleDateContract.cleanDate(end);
        return CycleDateContract.inWindow(day, s, e);
      }

      // Next period prediction window (پیش‌بینی قاعدگی بعدی)
      if (inFutureWindow(out.nextPeriodWindowStart, out.nextPeriodWindowEnd)) {
        items.add(
          AgendaItem(
            id: buildAgendaItemId(
              AgendaDomain.cycle,
              '${ctx.dateStr}_pred_period',
              ctx.dateStr,
            ),
            domain: AgendaDomain.cycle,
            sourceId: '${ctx.dateStr}_pred_period',
            title: 'پیش‌بینی دوره قاعدگی بعدی',
            dateStr: ctx.dateStr,
            category: Category.personal,
            priority: 0.8,
            deepLink: AgendaDeepLink(
              domain: AgendaDomain.cycle,
              targetId: ctx.dateStr,
            ),
          ),
        );
      }

      // PMS window prediction (پیش‌بینی PMS)
      if (inFutureWindow(out.pmsWindowStart, out.pmsWindowEnd)) {
        items.add(
          AgendaItem(
            id: buildAgendaItemId(
              AgendaDomain.cycle,
              '${ctx.dateStr}_pred_pms',
              ctx.dateStr,
            ),
            domain: AgendaDomain.cycle,
            sourceId: '${ctx.dateStr}_pred_pms',
            title: 'پیش‌بینی سندروم پیش از قاعدگی (PMS)',
            dateStr: ctx.dateStr,
            category: Category.personal,
            priority: 0.75,
            deepLink: AgendaDeepLink(
              domain: AgendaDomain.cycle,
              targetId: ctx.dateStr,
            ),
          ),
        );
      }

      // NOTE: Fertile window (پنجره باروری) is deliberately excluded from the main calendar agenda,
      // and remains visible exclusively within the private Cycle screen calendar.
    }

    return items;
  }
}
