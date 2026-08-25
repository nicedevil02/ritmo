import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/features/calendar/presentation/logic/today_calendar_convergence_helper.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// K31 — Upgraded Day Review Sheet
/// Features:
/// 1. Header: Full Jalali date + rhythm score (snapshot.rhythmScore) in Persian digits.
/// 2. 3 stats: Completed, Remaining, Overdue.
/// 3. List of uncompleted items with 3 quick buttons: "انجام شد", "فردا", "حذف تاریخ".
/// 4. Conflicts list from snapshot.conflicts with "رفع" (Fix) button.
/// 5. Narrative sentence (news tone, NO motivational/cheering text).
class DayReviewSheet extends StatelessWidget {
  const DayReviewSheet({
    super.key,
    required this.dateStr,
    required this.snapshot,
    required this.onReviewed,
  });

  final String dateStr;
  final DayAgendaSnapshot snapshot;
  final VoidCallback onReviewed;

  static void show(
    BuildContext context, {
    required String dateStr,
    required DayAgendaSnapshot snapshot,
    required VoidCallback onReviewed,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DayReviewSheet(
        dateStr: dateStr,
        snapshot: snapshot,
        onReviewed: onReviewed,
      ),
    );
  }

  String get _fullJalaliDateStr {
    final dt = DateKey.parse(dateStr);
    if (dt == null) {
      RitmoLog.error('DayReviewSheet', 'Invalid dateStr: $dateStr');
      return toPersianDigits(dateStr);
    }
    final j = Jalali.fromDateTime(dt);
    return '${ShamsiWeek.nameOf(j.weekDay)} ${toPersianDigits(j.day)} ${j.formatter.mN} ${toPersianDigits(j.year)}';
  }

  String get _narrativeSummary {
    final total = snapshot.completedCount + snapshot.remainingCount;
    final done = snapshot.completedCount;
    final rem = snapshot.remainingCount;
    if (total == 0) return 'برای این روز هیچ برنامه‌ای ثبت نشده است.';
    if (rem == 0)
      return '${toPersianDigits(done)} از ${toPersianDigits(total)} برنامه انجام شد.';
    return '${toPersianDigits(done)} از ${toPersianDigits(total)} کار انجام شد. ${toPersianDigits(rem)} کار باقی مانده است.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(
      top: Radius.circular(RitmoRadius.sheet),
    );

    final uncompleted = snapshot.items
        .where(
          (i) =>
              i.completion != AgendaCompletion.done &&
              i.completion != AgendaCompletion.skipped,
        )
        .toList();

    int overdueCount = 0;
    for (final item in snapshot.items) {
      if (item.completion == AgendaCompletion.overdue) overdueCount++;
    }

    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(RitmoSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header: Date + Rhythm Score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرور روز',
                      style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fullJalaliDateStr,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                // Rhythm Score Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 14, color: colors.primary),
                      const SizedBox(width: 2),
                      Text(
                        'امتیاز: ${toPersianDigits(snapshot.rhythmScore.round())}٪',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Three Stats Row
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'انجام‌شده',
                    value: toPersianDigits(snapshot.completedCount),
                    color: colors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    label: 'مانده',
                    value: toPersianDigits(snapshot.remainingCount),
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    label: 'معوقه',
                    value: toPersianDigits(overdueCount),
                    color: colors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Narrative summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : colors.card.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(RitmoRadius.card),
              ),
              child: Text(
                _narrativeSummary,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: colors.divider),
            const SizedBox(height: 12),

            // 4. Conflicts Section (if any)
            if (snapshot.conflicts.isNotEmpty) ...[
              Text(
                'تداخل‌های زمانی (${toPersianDigits(snapshot.conflicts.length)})',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                  color: colors.warning,
                ),
              ),
              const SizedBox(height: 6),
              ...snapshot.conflicts.map((conflict) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${conflict.itemA.title} ↔ ${conflict.itemB.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.0,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onReviewed();
                        },
                        child: const Text(
                          'رفع',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],

            // 3. Uncompleted items list
            Text(
              'برنامه‌های مانده (${toPersianDigits(uncompleted.length)})',
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            Expanded(
              child: uncompleted.isEmpty
                  ? Center(
                      child: Text(
                        'تمام برنامه‌های این روز انجام شده‌اند.',
                        style: TextStyle(
                          fontSize: 12.0,
                          color: colors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: uncompleted.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final item = uncompleted[index];
                        return _ReviewTile(
                          item: item,
                          dateStr: dateStr,
                          onReviewed: onReviewed,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );

    final sheetBody = Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        type: MaterialType.transparency,
        child: content,
      ),
    );

    if (!isGlass) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.85),
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.85),
      ),
      child: ClipRRect(
        borderRadius: sheetRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.glassTint,
              borderRadius: sheetRadius,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.70),
                width: 1.0,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: sheetRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
              child: sheetBody,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.item,
    required this.dateStr,
    required this.onReviewed,
  });

  final AgendaItem item;
  final String dateStr;
  final VoidCallback onReviewed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final helper = TodayCalendarConvergenceHelper();

    final isTaskOrGoal =
        item.domain == AgendaDomain.task ||
        item.domain == AgendaDomain.goalStep;

    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          if (item.timeOfDay != null) ...[
            const SizedBox(height: 2),
            Text(
              'ساعت: ${toPersianDigits(item.timeOfDay ?? "")}',
              style: TextStyle(fontSize: 12.0, color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),

          // 3 Quick Action Buttons: "انجام شد", "فردا", "حذف تاریخ"
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 1. Done
              _TileButton(
                label: 'انجام شد',
                icon: Icons.check_circle_outline_rounded,
                color: colors.success,
                onTap: () async {
                  await helper.completeItem(item);
                  DayAgendaService.instance.invalidateDate(dateStr);
                  onReviewed();
                },
              ),
              const SizedBox(width: 6),

              // 2. Tomorrow (tasks/goalSteps only)
              if (isTaskOrGoal) ...[
                _TileButton(
                  label: 'فردا',
                  icon: Icons.schedule_rounded,
                  color: colors.primary,
                  onTap: () async {
                    if (item.domain == AgendaDomain.task) {
                      final tomStr = DateKey.of(
                        DateKey.addDays(DateTime.now(), 1),
                      );
                      final task = await SimpleTaskRepository.instance.getById(
                        item.sourceId,
                      );
                      if (task != null) {
                        await SimpleTaskRepository.instance.updateTask(
                          task.copyWith(dueDate: tomStr),
                        );
                      }
                    }
                    DayAgendaService.instance.invalidateDate(dateStr);
                    onReviewed();
                  },
                ),
                const SizedBox(width: 6),

                // 3. Remove date (someday)
                _TileButton(
                  label: 'حذف تاریخ',
                  icon: Icons.calendar_today_outlined,
                  color: colors.textSecondary,
                  onTap: () async {
                    if (item.domain == AgendaDomain.task) {
                      final task = await SimpleTaskRepository.instance.getById(
                        item.sourceId,
                      );
                      if (task != null) {
                        await SimpleTaskRepository.instance.updateTask(
                          task.copyWith(dueDate: null),
                        );
                      }
                    }
                    DayAgendaService.instance.invalidateDate(dateStr);
                    onReviewed();
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        RitmoHapticsPolicy.tap();
        onTap();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
