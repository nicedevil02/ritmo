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
  final List<int> reminderLeadDays;
  final bool consentReminders;
  final Set<String> acknowledgedIds;

  const CycleAgendaSource({
    required this.cycleOutput,
    required this.cycleAllowed,
    this.periodRows = const [],
    this.isPregnancy = false,
    this.reminderLeadDays = const [3, 1],
    this.consentReminders = true,
    this.acknowledgedIds = const {},
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
    final reminderLeadDays = CycleSettings.getReminderLeadDays(settingsMap);
    final consentReminders = settingsMap['cycle_consent_reminders'] != 'false';

    if (!effectiveAllowed) {
      return const CycleAgendaSource(
        cycleOutput: null,
        cycleAllowed: false,
        periodRows: [],
        isPregnancy: false,
        reminderLeadDays: [3, 1],
        consentReminders: false,
        acknowledgedIds: {},
      );
    }

    CycleEngineOutput? cycleOutput;
    List<Map<String, dynamic>> periodRows = const [];
    Set<String> acknowledgedIds = const {};

    try {
      periodRows = await db.query('cycle_periods', orderBy: 'startDate ASC');

      try {
        final acks = await db.query(
          'cycle_confirmations',
          columns: ['id'],
          where: "kind = 'REMINDER_ACK' AND answer = 'ACKNOWLEDGED'",
        );
        acknowledgedIds = acks
            .map((r) => (r['id'] as String?)?.replaceFirst('ack_', ''))
            .whereType<String>()
            .toSet();
      } catch (e) {
        RitmoLog.debug('CycleAgendaSource', 'No cycle_confirmations table or query failed: $e');
      }

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
      reminderLeadDays: reminderLeadDays,
      consentReminders: consentReminders,
      acknowledgedIds: acknowledgedIds,
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

    // 1. Check actual recorded/past periods from cycle_periods (نشانگر وضعیت زیستی روز — Event/Contextual)
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
              kind: AgendaItemKind.event,
              itemType: AgendaItemType.optional,
              sourceId: '${ctx.dateStr}_actual',
              title: 'دوره قاعدگی (روز ${toPersianDigits(dayNum)})',
              dateStr: ctx.dateStr,
              category: Category.personal,
              priority: 0.2,
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
              kind: AgendaItemKind.event,
              itemType: AgendaItemType.optional,
              sourceId: '${ctx.dateStr}_actual_open',
              title: 'دوره قاعدگی (روز ${toPersianDigits(dayNum)})',
              dateStr: ctx.dateStr,
              category: Category.personal,
              priority: 0.2,
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

    // 2. Future prediction items & reminders
    final out = cycleOutput;
    if (out != null &&
        out.hasData &&
        out.currentPhase != CyclePhase.pregnancy) {
      final targetPeriod =
          out.nextPeriodPrediction ?? out.nextPeriodWindowStart;

      final todayClean = CycleDateContract.cleanDate(DateTime.now());
      final isDayArrived = ctx.isToday || !day.isAfter(todayClean);

      // Period prediction reminders based on lead days (e.g. 1 to 3 days before)
      if (targetPeriod != null) {
        final cleanPeriodDate = CycleDateContract.cleanDate(targetPeriod);

        // A. Calendar event marker on the predicted period start day (نشانگر تقویمی در روز اصلی شروع)
        if (cleanPeriodDate == day) {
          items.add(
            AgendaItem(
              id: buildAgendaItemId(
                AgendaDomain.cycle,
                '${ctx.dateStr}_predicted_period_start',
                ctx.dateStr,
              ),
              domain: AgendaDomain.cycle,
              kind: AgendaItemKind.event,
              itemType: AgendaItemType.optional,
              sourceId: '${ctx.dateStr}_predicted_period_start',
              title: 'شروع احتمالی قاعدگی',
              dateStr: ctx.dateStr,
              category: Category.personal,
              priority: 0.3,
              deepLink: AgendaDeepLink(
                domain: AgendaDomain.cycle,
                targetId: ctx.dateStr,
              ),
            ),
          );
        }

        // B. Point-in-time lead reminders (یادآوری‌های قبل از موعد تنظیمی کاربر — فقط وقتی آن روز فرا می‌رسد)
        if (consentReminders && isDayArrived) {
          for (final lead in reminderLeadDays) {
            final reminderDate = cleanPeriodDate.subtract(Duration(days: lead));
            if (reminderDate == day) {
              final leadText =
                  lead == 1 ? '۱ روز' : '${toPersianDigits(lead)} روز';
              final sourceId = '${ctx.dateStr}_lead_period_$lead';
              final isAck = acknowledgedIds.contains(sourceId);

              items.add(
                AgendaItem(
                  id: buildAgendaItemId(
                    AgendaDomain.cycle,
                    sourceId,
                    ctx.dateStr,
                  ),
                  domain: AgendaDomain.cycle,
                  kind: AgendaItemKind.reminder,
                  completion:
                      isAck ? AgendaCompletion.done : AgendaCompletion.none,
                  sourceId: sourceId,
                  title: 'یادآوری: $leadText تا شروع احتمالی قاعدگی',
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
          }
        }
      }

      // PMS reminder (1 day before estimated PMS start — فقط وقتی آن روز فرا می‌رسد)
      final pmsStart = out.pmsWindowStart;
      if (consentReminders && isDayArrived && pmsStart != null) {
        final cleanPmsDate = CycleDateContract.cleanDate(pmsStart);
        final pmsReminderDate = cleanPmsDate.subtract(const Duration(days: 1));
        if (pmsReminderDate == day) {
          final sourceId = '${ctx.dateStr}_lead_pms';
          final isAck = acknowledgedIds.contains(sourceId);

          items.add(
            AgendaItem(
              id: buildAgendaItemId(
                AgendaDomain.cycle,
                sourceId,
                ctx.dateStr,
              ),
              domain: AgendaDomain.cycle,
              kind: AgendaItemKind.reminder,
              completion:
                  isAck ? AgendaCompletion.done : AgendaCompletion.none,
              sourceId: sourceId,
              title: 'یادآوری: احتمال شروع علائم PMS از فردا',
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
      }
    }

    return items;
  }
}
