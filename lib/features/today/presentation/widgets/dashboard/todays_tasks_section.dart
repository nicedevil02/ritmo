import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/today/presentation/widgets/reshuffle_preview_sheet.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// سکشن «کارهای امروز» — فقط لایهٔ نمایش.
///
/// ورودی `tasks` همان ساختار Map قبلی است، اما حالا از Agenda ساخته میشود و
/// نه فقط از روتینهای دارای occurrence. پس دو نوع ردیف داریم:
///
/// * ردیف روتین — `task['routine']` پر است و رفتار قبلی (تیک/جزئیات) را دارد.
/// * ردیف اجندا — `task['routine']` خالی و `task['agendaItem']` پر است؛ مثل
///   تمرین ورزشی یا دوز دارو. این ردیفها نمایش داده و به بخش صاحبشان
///   راهنمایی میشوند، ولی وانمود نمیکنیم که تیکشان اینجا کار میکند.
///
/// دکمهٔ «رفع تداخل» دیگر همیشگی نیست: فقط وقتی ظاهر میشود که دستکم یک
/// ردیف با `hasConflict` علامت خورده باشد، و تعداد را هم نشان میدهد.
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

  /// اختیاری: پرش به بخش صاحبِ یک آیتم اجندا (ورزش، کارها، …).
  final void Function(AgendaDomain domain)? onOpenAgendaDomain;

  int get _conflictCount =>
      tasks.where((t) => t['hasConflict'] == true).length;

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
                // فقط وقتی تداخل واقعی وجود دارد.
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
          // حداکثر ۴ کارت اینجا رندر میشود؛ باقی از «مشاهده همه».
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
    final title = (task['title'] as String?) ??
        routine?.title ??
        item?.title ??
        '—';

    final time = (task['time'] as String?) ?? '--:--';
    final hasTime = time.isNotEmpty && time != '--:--';
    final duration = task['durationMinutes'] as int?;
    final domainLabel = task['domainLabel'] as String?;

    final metaParts = <String>[
      if (hasTime)
        '${l10n.timeLabel} ${toPersianDigits(time)}'
      else
        'زمان آزاد',
      if (duration != null && duration > 0)
        '${toPersianDigits('$duration')} دقیقه',
      if (domainLabel != null && domainLabel.isNotEmpty) domainLabel,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: RitmoTheme.glassCardLight(
        borderRadius: 18,
        color: colors.card.withValues(alpha: 0.55),
        child: Container(
          decoration: hasConflict
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.warning.withValues(alpha: 0.55),
                  ),
                )
              : null,
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
                    RitmoHaptics.warning();
                    onStartTask(routine);
                  },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.lg, vertical: RitmoSpacing.md),
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
                            color: isCompleted
                                ? colors.textSecondary
                                : colors.textPrimary,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
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
                                color: