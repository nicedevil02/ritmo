import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_dialog.dart';
import 'package:ritmo/features/routines/presentation/universal_planner_sheet.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';

/// K25 — Actionable Empty Day View
/// Displayed when a day has no items scheduled.
/// News tone: "برای این روز چیزی ثبت نشده." (no motivational talk).
/// 3 action buttons:
/// 1. "کارهای بدون تاریخ" — sheet with someday tasks to schedule today.
/// 2. "کپی از دیروز" — confirmation dialog + copy yesterday's items.
/// 3. "افزودن" — open UniversalPlannerSheet with prefilled date.
class EmptyDayView extends StatelessWidget {
  const EmptyDayView({
    super.key,
    required this.date,
    required this.onRefreshRequested,
    this.snapshot,
  });

  final DateTime date;
  final VoidCallback onRefreshRequested;
  final DayAgendaSnapshot? snapshot;

  String get _dateStr => DateKey.of(date);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final disabledModules = <String>[];
    if (snapshot != null && snapshot!.enabledDomains.isNotEmpty) {
      if (snapshot!.enabledDomains[AgendaDomain.prayer] == false) {
        disabledModules.add('نماز');
      }
      if (snapshot!.enabledDomains[AgendaDomain.sport] == false) {
        disabledModules.add('ورزش');
      }
      if (snapshot!.enabledDomains[AgendaDomain.medicine] == false) {
        disabledModules.add('دارو');
      }
      if (snapshot!.enabledDomains[AgendaDomain.course] == false) {
        disabledModules.add('دوره‌ها');
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'برای این روز چیزی ثبت نشده.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.0, color: colors.textSecondary),
            ),
            if (disabledModules.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(RitmoRadius.badge),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Text(
                  'ماژول‌های غیرفعال: ${disabledModules.join("، ")}',
                  style: TextStyle(fontSize: 11.0, color: colors.textTertiary),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Button 1: Someday tasks
            RitmoSecondaryButton(
              label: 'کارهای بدون تاریخ',
              icon: Icons.inventory_2_rounded,
              fullWidth: true,
              onPressed: () => _openSomedayTasksSheet(context),
            ),
            const SizedBox(height: 10),

            // Button 2: Copy from yesterday
            RitmoSecondaryButton(
              label: 'کپی از دیروز',
              icon: Icons.copy_rounded,
              fullWidth: true,
              onPressed: () => _confirmCopyFromYesterday(context),
            ),
            const SizedBox(height: 10),

            // Button 3: Add new item
            RitmoPrimaryButton(
              label: 'افزودن',
              icon: Icons.add_rounded,
              fullWidth: true,
              onPressed: () => UniversalPlannerSheet.show(
                context: context,
                onSaved: onRefreshRequested,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSomedayTasksSheet(BuildContext context) async {
    final somedayTasks = await SimpleTaskRepository.instance.someday();
    if (!context.mounted) return;

    if (somedayTasks.isEmpty) {
      RitmoToast.show(context, 'هیچ کار بدون تاریخی وجود ندارد');
      return;
    }

    final parentContext = context;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SomedayTasksPickerSheet(
        tasks: somedayTasks,
        targetDateStr: _dateStr,
        parentContext: parentContext,
        onScheduled: () {
          DayAgendaService.instance.invalidateDate(_dateStr);
          onRefreshRequested();
        },
      ),
    );
  }

  Future<void> _confirmCopyFromYesterday(BuildContext context) async {
    final confirmed = await RitmoDialog.show(
      context,
      title: 'کپی از دیروز',
      content: 'کارهای دیروز به این روز اضافه شوند؟',
      confirmLabel: 'تأیید',
      cancelLabel: 'انصراف',
    );

    if (confirmed == true && context.mounted) {
      RitmoHapticsPolicy.tap();
      final yesterday = date.subtract(const Duration(days: 1));
      final yesterdayStr = DateKey.of(yesterday);

      final db = await DatabaseHelper.instance.database;
      final yesterdayTasks = await db.query(
        'simple_tasks',
        where: 'dueDate = ?',
        whereArgs: [yesterdayStr],
      );

      if (!context.mounted) return;

      if (yesterdayTasks.isEmpty) {
        RitmoToast.show(context, 'چیزی برای کپی کردن نبود');
        return;
      }

      final createdIds = <String>[];
      for (final row in yesterdayTasks) {
        final task = SimpleTask.fromMap(row);
        final newTask = await SimpleTaskRepository.instance.create(
          title: task.title,
          dueDate: _dateStr,
          dueTime: task.dueTime,
          note: task.note,
        );
        createdIds.add(newTask.id);
      }

      DayAgendaService.instance.invalidateDate(_dateStr);
      onRefreshRequested();

      if (context.mounted) {
        final count = createdIds.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count کار از دیروز کپی شد'),
            action: SnackBarAction(
              label: 'بازگشت (Undo)',
              onPressed: () async {
                for (final id in createdIds) {
                  await SimpleTaskRepository.instance.delete(id);
                }
                DayAgendaService.instance.invalidateDate(_dateStr);
                onRefreshRequested();
              },
            ),
          ),
        );
      }
    }
  }
}

/// Sheet displaying someday tasks to schedule on the selected date.
class _SomedayTasksPickerSheet extends StatelessWidget {
  const _SomedayTasksPickerSheet({
    required this.tasks,
    required this.targetDateStr,
    required this.parentContext,
    required this.onScheduled,
  });

  final List<SimpleTask> tasks;
  final String targetDateStr;
  final BuildContext parentContext;
  final VoidCallback onScheduled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RitmoRadius.sheet),
            ),
          ),
          padding: const EdgeInsets.all(RitmoSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'کارهای بدون تاریخ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final task = tasks[i];
                    return ListTile(
                      title: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final updated = task.copyWith(dueDate: targetDateStr);
                          await SimpleTaskRepository.instance.updateTask(
                            updated,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                          onScheduled();
                          if (parentContext.mounted) {
                            RitmoToast.show(
                              parentContext,
                              'کار به تاریخ انتخابی منتقل شد',
                            );
                          }
                        },
                        child: const Text(
                          'افزودن به این روز',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
