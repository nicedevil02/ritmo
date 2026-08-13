import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/ux/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/today/presentation/widgets/reshuffle_preview_sheet.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// سکشن «کارهای امروز» — فقط لایهٔ نمایش.
///
/// از این پس ورودی از Agenda ساخته می‌شود، نه فقط از روتین‌ها. پس دو نوع ردیف داریم:
/// * ردیف روتین: `task['routine']` پر است و رفتار قبلی حفظ می‌شود.
/// * ردیف اجندا: `task['agendaItem']` پر است (تمرین ورزشی، کار ساده، دوز دارو…).
///
/// دکمهٔ «رفع تداخل» دیگر همیشگی نیست و فقط با تداخل واقعی دیده می‌شود.
class TodaysTasksSection extends StatelessWidget {
  const TodaysTasksSection({
    super.key,
    required this.tasks,
    required this.onOpenDetails,
    required this.onStartTask,
    required this.onReshuffleApplied,
    this.onViewAll,
    this.onOpenAgendaDomain,
  });

  final List<Map<String, dynamic>> tasks;
  final Function(Routine) onOpenDetails;
  final Function(Routine) onStartTask;
  final VoidCallback onReshuffleApplied;
  final VoidCallback? onViewAll;

  /// اختیاری: پرش به بخش صاحبِ آیتم اجندا.
  final void Function(AgendaDomain domain)? onOpenAgendaDomain;

  int get _conflictCount => tasks.where((t) => t['hasConflict'] == true).length;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final conflictCount = _conflictCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      l10n.todaysTasksTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.sectionTitle,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ),
                  if (tasks.length > 4) ...[
                    const SizedBox(width: RitmoSpacing.sm),
                    Text(
                      '${toPersianDigits('${tasks.length}')} مورد',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (conflictCount > 0) ...[
                  _ConflictChip(
                    count: conflictCount,
                    label: l10n.resolveConflictBtn,
                    onTap: () => _openReshuffleSheet(context),
                  ),
                  const SizedBox(width: RitmoSpacing.md),
                ],
                if (onViewAll != null)
                  GestureDetector(
                    onTap: onViewAll,
                    child: Text(
                      l10n.viewAll,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                        fontFamily: 'Vazirmatn',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.md),
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
            child: Text(
              l10n.noRoutinesToday,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                fontFamily: 'Vazirmatn',
              ),
            ),
          )
        else
          ...tasks.take(4).map((task) => _buildTaskCard(context, task)),
      ],
    );
  }

  void _openReshuffleSheet(BuildContext context) {
    RitmoHaptics.tap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ReshufflePreviewSheet(onApplied: onReshuffleApplied),
    );
  }

  Category _categoryOf(Map<String, dynamic> task) {
    final routine = task['routine'] as Routine?;
    if (routine != null) return routine.category;
    final item = task['agendaItem'] as AgendaItem?;
    if (item != null) return item.category;
    final name = (task['category'] as String?) ?? '';
    return Category.values.firstWhere(
      (c) => c.name == name,
      orElse: () => Category.custom,
    );
  }

  Widget _buildTaskCard(BuildContext context, Map<String, dynamic> task) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final isCompleted = task['isCompleted'] == true;
    final hasConflict = task['hasConflict'] == true;
    final routine = task['routine'] as Routine?;
    final item = task['agendaItem'] as AgendaItem?;
    final title = (task['title'] as String?) ?? routine?.title ?? item?.title ?? '—';

    final time = (task['time'] as String?) ?? '--:--';
    final hasTime = time.isNotEmpty && time != '--:--';
    final duration = task['durationMinutes'] as int?;
    final domainLabel = task['domainLabel'] as String?;
    final conflictWith = task['conflictWith'] as String?;

    final metaParts = <String>[
      if (hasTime) '${l10n.timeLabel} ${toPersianDigits(time)}' else 'زمان آزاد',
      if (duration != null && duration > 0) '${toPersianDigits('$duration')} دقیقه',
      if (domainLabel != null && domainLabel.isNotEmpty) domainLabel,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: hasConflict
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.warning.withValues(alpha: 0.55)),
            )
          : null,
      child: RitmoTheme.glassCardLight(
        borderRadius: 18,
        color: colors.card.withValues(alpha: 0.55),
        child: InkWell(
          onTap: () {
            RitmoHaptics.tap();
            if (routine != null) {
              onOpenDetails(routine);
            } else {
              _showAgendaSheet(context, task);
            }
          },
          onLongPress: routine == null
              ? null
              : () {
                  RitmoHaptics.tap();
                  onStartTask(routine);
                },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.lg,
              vertical: RitmoSpacing.md,
            ),
            child: Row(
              children: [
                _categoryIcon(_categoryOf(task)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? colors.textSecondary : colors.textPrimary,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        metaParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.textSecondary,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                      if (hasConflict) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              size: 11,
                              color: colors.warning,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                conflictWith == null
                                    ? 'تداخل زمانی'
                                    : 'تداخل با $conflictWith',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors.warning,
                                  fontFamily: 'Vazirmatn',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: RitmoSpacing.sm),
                if (isCompleted)
                  Icon(CupertinoIcons.checkmark_alt_circle_fill,
                      size: 20, color: colors.success)
                else if (routine != null)
                  Icon(CupertinoIcons.circle, size: 20, color: colors.border)
                else
                  Icon(CupertinoIcons.chevron_left,
                      size: 16, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// برای آیتم‌هایی که مالکشان یک ماژول دیگر است، اینجا تیک الکی نمی‌زنیم؛
  /// توضیح می‌دهیم کجا ثبت می‌شود.
  void _showAgendaSheet(BuildContext context, Map<String, dynamic> task) {
    final item = task['agendaItem'] as AgendaItem?;
    if (item == null) return;

    RitmoSheetScaffold.present<void>(
      context: context,
      semanticsLabel: 'جزئیات ${item.title}',
      builder: (ctx) {
        final colors = ctx.colors;
        final owner = task['domainLabel'] as String? ?? _domainLabel(item.domain);
        final duration = item.durationMinutes;
        final time = item.hasValidTimeOfDay ? item.timeOfDay : null;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
                fontFamily: 'Vazirmatn',
              ),
            ),
            if (item.subtitle != null && item.subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: RitmoSpacing.xs),
              Text(
                item.subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
            const SizedBox(height: RitmoSpacing.md),
            Wrap(
              spacing: RitmoSpacing.sm,
              runSpacing: RitmoSpacing.sm,
              children: [
                _InfoPill(text: owner, color: colors.primary),
                if (time != null)
                  _InfoPill(
                    text: 'ساعت ${toPersianDigits(time)}',
                    color: colors.accent,
                  ),
                if (duration != null && duration > 0)
                  _InfoPill(
                    text: '${toPersianDigits('$duration')} دقیقه',
                    color: colors.accent,
                  ),
                if (task['hasConflict'] == true)
                  _InfoPill(text: 'تداخل زمانی', color: colors.warning),
              ],
            ),
            const SizedBox(height: RitmoSpacing.lg),
            Text(
              'این مورد از بخش «$owner» می‌آید و ثبت انجامش هم همانجا انجام می‌شود.',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.6,
                fontFamily: 'Vazirmatn',
              ),
            ),
            const SizedBox(height: RitmoSpacing.lg),
            Row(
              children: [
                if (onOpenAgendaDomain != null) ...[
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onOpenAgendaDomain!(item.domain);
                      },
                      child: Text('رفتن به $owner'),
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.sm),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('باشه'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _domainLabel(AgendaDomain domain) {
    switch (domain.name) {
      case 'sport':
        return 'ورزش';
      case 'medicine':
        return 'دارو';
      case 'task':
        return 'کارها';
      case 'course':
        return 'دوره‌ها';
      case 'konkur':
        return 'کنکور';
      case 'goalStep':
        return 'اهداف';
      case 'event':
        return 'رویداد';
      default:
        return 'برنامه';
    }
  }

  Widget _categoryIcon(Category category) {
    late final Color color;
    late final IconData icon;

    switch (category.name) {
      case 'medical':
        color = const Color(0xffFF6B6B);
        icon = CupertinoIcons.heart_fill;
      case 'religious':
        color = const Color(0xff9B89FF);
        icon = CupertinoIcons.moon_stars_fill;
      case 'learning':
        color = const Color(0xffA78BFA);
        icon = CupertinoIcons.book_fill;
      case 'fitness':
        color = const Color(0xff34D399);
        icon = CupertinoIcons.flame_fill;
      case 'work':
        color = const Color(0xff5B8AF5);
        icon = CupertinoIcons.briefcase_fill;
      case 'personal':
        color = const Color(0xffF5B95B);
        icon = CupertinoIcons.person_fill;
      case 'free':
        color = const Color(0xff2DD4BF);
        icon = CupertinoIcons.sparkles;
      case 'konkur':
        color = const Color(0xff2563EB);
        icon = CupertinoIcons.doc_text_fill;
      default:
        color = const Color(0xffE25C9A);
        icon = CupertinoIcons.circle_grid_hex_fill;
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(RitmoRadius.chip),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _ConflictChip extends StatelessWidget {
  const _ConflictChip({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: '$label — ${toPersianDigits('$count')} مورد',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
            border: Border.all(color: colors.warning.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 11,
                color: colors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                '$label (${toPersianDigits('$count')})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.warning,
                  fontFamily: 'Vazirmatn',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          fontFamily: 'Vazirmatn',
        ),
      ),
    );
  }
}
