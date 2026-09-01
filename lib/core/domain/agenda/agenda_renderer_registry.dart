import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_action_handler.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/event_agenda_renderer.dart';
import 'package:ritmo/core/domain/agenda/quran_dhikr_agenda_renderer.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_geometry.dart';
import 'package:ritmo/features/routines/presentation/universal_planner_sheet.dart';
import 'package:ritmo/features/routines/presentation/widgets/routine_snooze_bottom_sheet.dart';
import 'package:ritmo/features/routines/shared/routine_actions.dart';
import 'package:ritmo/features/routines/shared/widgets/routine_card.dart';
import 'package:ritmo/features/routines/shared/widgets/routine_details_sheet.dart';
import 'package:ritmo/features/routines/shared/widgets/routine_niyyah_sheet.dart';
import 'package:ritmo/features/today/presentation/active_timer_overlay.dart';
import 'package:ritmo/features/worship/presentation/widgets/prayer_agenda_card.dart';
import 'package:ritmo/features/worship/presentation/widgets/prayer_sheet.dart';
import 'package:ritmo/features/worship/domain/prayer_target.dart';

abstract class AgendaTileRenderer {
  const AgendaTileRenderer();

  Widget build(
    BuildContext context,
    AgendaItem item, {
    required VoidCallback onChanged,
  });
}

class AgendaRendererRegistry {
  static final Map<AgendaDomain, AgendaTileRenderer> _registry = {
    AgendaDomain.prayer: const PrayerAgendaRenderer(),
    AgendaDomain.routine: const RoutineAgendaRenderer(),
    AgendaDomain.event: const EventAgendaRenderer(),
  };

  static void register(AgendaDomain domain, AgendaTileRenderer renderer) {
    _registry[domain] = renderer;
  }

  static Widget render(
    BuildContext context,
    AgendaItem item, {
    required VoidCallback onChanged,
  }) {
    if (item.domain == AgendaDomain.mustahab) {
      final practice = item.meta['practice'] as Map<String, dynamic>? ?? {};
      final type = practice['practiceType'] as String?;
      if (type == 'QURAN' || type == 'DHIKR') {
        return const QuranDhikrAgendaRenderer().build(
          context,
          item,
          onChanged: onChanged,
        );
      }
    }

    final renderer = _registry[item.domain] ?? const DefaultAgendaRenderer();
    return renderer.build(context, item, onChanged: onChanged);
  }
}

class PrayerAgendaRenderer extends AgendaTileRenderer {
  const PrayerAgendaRenderer();

  Duration get expiringSoonThreshold => const Duration(minutes: 30);

  @override
  Widget build(
    BuildContext context,
    AgendaItem item, {
    required VoidCallback onChanged,
  }) {
    final practice = item.meta['practice'] as Map<String, dynamic>? ?? {};
    final isDone = item.isCompleted;
    final isSkipped = item.completion == AgendaCompletion.skipped;
    final latestSnooze = practice['lastDeferredUntil'] as int? ?? 0;
    final isSnoozed = latestSnooze > DateTime.now().millisecondsSinceEpoch;
    final deferCount = practice['deferCount'] as int? ?? 0;

    String? snoozeText;
    if (isSnoozed && latestSnooze > 0) {
      final time = DateTime.fromMillisecondsSinceEpoch(latestSnooze);
      final hour = time.hour.toString().padLeft(2, '0');
      final min = time.minute.toString().padLeft(2, '0');
      snoozeText = 'تعویق تا ${toPersianDigits("$hour:$min")}';
    }

    // Expiration alerts
    var isExpired = false;
    var isExpiringSoon = false;

    final todayStr = DateKey.today();
    final isToday = item.dateStr == todayStr;

    if (isToday && item.windowEnd != null && !isDone && !isSkipped) {
      final now = DateTime.now();
      isExpired = now.isAfter(item.windowEnd!);
      isExpiringSoon =
          !isExpired &&
          now.isAfter(item.windowEnd!.subtract(expiringSoonThreshold));
    }

    final hasReminder = (practice['reminderEnabled'] as int? ?? 0) == 1;

    return PrayerAgendaCard(
      title: item.title,
      timeStr: item.timeOfDay ?? '--:--',
      isDone: isDone,
      isSkipped: isSkipped,
      isSnoozed: isSnoozed,
      snoozeText: snoozeText,
      deferCount: deferCount,
      hasReminder: hasReminder,
      isExpired: isExpired,
      isExpiringSoon: isExpiringSoon,
      onToggle: (val) async {
        final explicitGroup = practice['groupKey'] as String?;
        String group;
        if (explicitGroup != null && explicitGroup.isNotEmpty) {
          group = explicitGroup;
        } else {
          final combined = '${item.id}:${item.sourceId}'.toLowerCase();
          if (combined.contains('dhuhr') || combined.contains('asr')) {
            group = 'DHUHR_ASR';
          } else if (combined.contains('maghrib') || combined.contains('isha')) {
            group = 'MAGHRIB_ISHA';
          } else if (combined.contains('fasting') ||
              combined.contains('ramadan')) {
            group = 'RAMADAN_FAST';
          } else {
            group = 'FAJR';
          }
        }

        if (val) {
          final targetDate = DateTime.tryParse(item.dateStr) ?? DateTime.now();
          final target = await PrayerTarget.fromGroupKey(group, targetDate);
          if (context.mounted) {
            await PrayerSheet.show(context, target);
          }
          onChanged();
          return;
        }

        await AgendaActionHandler.instance.togglePrayer(
          group: group,
          isDone: false,
          dateStr: item.dateStr,
        );
        onChanged();
      },
      onSnooze: () async {
        // Show snooze dialog
        await _showSnoozeBottomSheet(context, item, practice, onChanged);
      },
      onSkip: () async {
        // Show skip confirmation dialog
        await _showSkipConfirmationDialog(context, item, practice, onChanged);
      },
      onReminderSettings: () {
        // We can optionally delegate settings opening, but for the scope of mirroring,
        // let's show a snackbar or implement it if settings dialog is accessible.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تنظیمات یادآور نماز را می‌توانید در بخش عبادات تغییر دهید.',
              style: TextStyle(fontFamily: 'Vazirmatn'),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSnoozeBottomSheet(
    BuildContext context,
    AgendaItem item,
    Map<String, dynamic> practice,
    VoidCallback onChanged,
  ) async {
    var selectedMinutes = 15;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return RitmoCustomDialog(
              title: 'تعویق نماز',
              icon: CupertinoIcons.time,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'نماز را برای چند دقیقه به تعویق می‌اندازید؟',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<int>(
                    value: selectedMinutes,
                    items: const [
                      DropdownMenuItem(
                        value: 5,
                        child: Text('۵ دقیقه'),
                      ),
                      DropdownMenuItem(
                        value: 10,
                        child: Text('۱۰ دقیقه'),
                      ),
                      DropdownMenuItem(
                        value: 15,
                        child: Text('۱۵ دقیقه'),
                      ),
                      DropdownMenuItem(
                        value: 30,
                        child: Text('۳۰ دقیقه'),
                      ),
                      DropdownMenuItem(
                        value: 45,
                        child: Text('۴۵ دقیقه'),
                      ),
                      DropdownMenuItem(
                        value: 60,
                        child: Text('۱ ساعت'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedMinutes = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                RitmoSecondaryButton(
                  label: 'انصراف',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                RitmoPrimaryButton(
                  label: 'ثبت تعویق',
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final outcome = await AgendaActionHandler.instance
                          .snoozePrayer(
                            practiceIds: [practice['id'] as String],
                            minutes: selectedMinutes,
                            dateStr: item.dateStr,
                          );
                      if (context.mounted) {
                        if (outcome is SnoozeRefused) {
                          RitmoToast.show(context, outcome.userMessage);
                        } else {
                          onChanged();
                        }
                      }
                    } catch (e, st) {
                      RitmoLog.error(
                        'AgendaRendererRegistry',
                        'snoozePrayer failed',
                        e,
                        st,
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSkipConfirmationDialog(
    BuildContext context,
    AgendaItem item,
    Map<String, dynamic> practice,
    VoidCallback onChanged,
  ) async {
    final addToQada = await RitmoDialog.show(
      context,
      title: 'ثبت نماز قضای ${item.title}',
      content:
          'آیا مایلید نماز امروز (${item.title}) را به بدهی‌های عبادی (نماز قضا) اضافه کنید؟',
      confirmLabel: 'بله، اضافه کن',
      cancelLabel: 'خیر',
    );

    if (addToQada != null) {
      await AgendaActionHandler.instance.skipPrayer(
        practices: [
          {
            'id': practice['id'] as String,
            'subType': practice['subType'] as String?,
            'title': practice['title'] as String?,
            'practiceType': practice['practiceType'] as String?,
          },
        ],
        addToQada: addToQada,
        dateStr: item.dateStr,
      );

      if (addToQada && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'نماز قضای ${item.title} به بدهی‌های شما اضافه شد.',
              style: const TextStyle(fontFamily: 'Vazirmatn'),
            ),
            backgroundColor: const Color(0xffD4A843),
          ),
        );
      }
      onChanged();
    }
  }
}

class RoutineAgendaRenderer extends AgendaTileRenderer {
  const RoutineAgendaRenderer();

  @override
  Widget build(
    BuildContext context,
    AgendaItem item, {
    required VoidCallback onChanged,
  }) {
    final routineMap = item.meta['routine'] as Map<String, dynamic>? ?? {};
    final routine = Routine.fromMap(routineMap);
    final isDone = item.isCompleted;

    return RoutineCard(
      routine: routine,
      isCompleted: isDone,
      displayStreak: routineMap['streak'] as int? ?? (item.meta['streak'] as int? ?? 0),
      customCategoriesMap: (item.meta['customCategoriesMap'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as dynamic),
      ) ?? const {},
      onTap: () {
        if (isDone) {
          RoutineDetailsSheet.show(
            context: context,
            routine: routine,
            targetDate: item.dateStr,
            onReverted: onChanged,
          );
        } else {
          RoutineNiyyahSheet.show(
            context: context,
            routine: routine,
            onStartTimer: (selectedMode) async {
              final todayStr = DateKey.today();
              final isToday = item.dateStr == todayStr;
              if (isToday) {
                unawaited(
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActiveTimerOverlay(
                        routine: routine,
                        completionMode: selectedMode,
                        dateStr: item.dateStr, // T4: item's date
                        onCompleted: (outcome) {
                          // T6: only on confirmed completion
                          Navigator.pop(context);
                          onChanged();
                        },
                        onCancelled: () {
                          // T6: neutral — no success
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                );
              } else {
                await RoutineActions.completeRoutine(
                  context: context,
                  routineId: routine.id,
                  resultType: selectedMode,
                  dateStr: item.dateStr,
                  onDone: onChanged,
                );
              }
            },
            onCompleteInstantly: (selectedMode, duration) async {
              await RoutineActions.completeRoutine(
                context: context,
                routineId: routine.id,
                resultType: selectedMode,
                dateStr: item.dateStr,
                onDone: onChanged,
              );
            },
            onSnooze: () async {
              RoutineSnoozeBottomSheet.show(
                context: context,
                routine: routine,
                onSnoozeSelected: (minutes) async {
                  await RoutineActions.snoozeRoutine(
                    context: context,
                    routineId: routine.id,
                    dateStr: item.dateStr,
                    minutes: minutes,
                    onDone: onChanged,
                  );
                },
              );
            },
            onEdit: () async {
              final rMap = {
                'id': routine.id,
                'title': routine.title,
                'description': routine.description,
                'category': routine.category.name,
                'routineType': routine.routineType.name,
                'notificationLevel': routine.notificationLevel.name,
                'isEssential': routine.isEssential ? 1 : 0,
                'energyRule': routine.energyRule.name,
                'priority': routine.priority,
                'targetDurationMinutes': routine.targetDurationMinutes,
                'lightDurationMinutes': routine.lightDurationMinutes,
                'minimalDurationMinutes': routine.minimalDurationMinutes,
              };

              await Navigator.push(
                context,
                PageRouteBuilder(
                  opaque: false,
                  barrierDismissible: true,
                  pageBuilder: (context, _, _) => UniversalPlannerSheet(
                    routineToEdit: rMap,
                    onSaved: () {
                      onChanged();
                    },
                  ),
                ),
              );
            },
            onViewDetails: () async {
              unawaited(
                RoutineDetailsSheet.show(
                  context: context,
                  routine: routine,
                  targetDate: item.dateStr,
                  onReverted: onChanged,
                ),
              );
            },
          );
        }
      },
    );
  }
}

class DefaultAgendaRenderer extends AgendaTileRenderer {
  const DefaultAgendaRenderer();

  @override
  Widget build(
    BuildContext context,
    AgendaItem item, {
    required VoidCallback onChanged,
  }) {
    final colors = context.colors;
    final isDone = item.isCompleted;
    // All module/system items are read-only mirrors in the calendar screen
    final isCompletable =
        item.domain == AgendaDomain.prayer ||
        item.domain == AgendaDomain.course ||
        item.domain == AgendaDomain.goalStep ||
        item.domain == AgendaDomain.worshipDebt ||
        item.domain == AgendaDomain.routine ||
        item.domain == AgendaDomain.mustahab;

    final Widget card = Container(
      constraints: BoxConstraints(
        minHeight: CalendarGeometry.effectiveRegistryCardHeight(context) * 0.7,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.circle, size: 14, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: RitmoTextStyles.label(
                    colors.textPrimary,
                  ).copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty)
                  Text(
                    item.subtitle!,
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
              ],
            ),
          ),
          if (item.hasValidTimeOfDay) ...[
            Text(
              item.timeOfDay!,
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
            const SizedBox(width: 8),
          ],
          if (isCompletable) ...[
            Icon(
              isDone
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: isDone ? colors.success : colors.textSecondary,
              size: 20,
            ),
          ],
        ],
      ),
    );

    if (isCompletable) {
      return GestureDetector(
        onTap: () async {
          await AgendaActionHandler.instance.toggleAgendaItem(
            item: item,
            isDone: !isDone,
            context: context,
          );
          onChanged();
        },
        child: card,
      );
    }

    return card;
  }
}
