import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/calendar/presentation/logic/today_calendar_convergence_helper.dart';

/// کارت «مسیر امروز» — خط زمانی فشردهٔ اکنون ← بعدی به همراه یک بینش هوشمند.
///
/// هر ردیف خودش دکمه است و مستقیم به همان آیتم در تقویم لینک میدهد؛ به همین دلیل
/// دکمهٔ تکراری «مشاهده در تقویم» در هدر و آیکون تقویم داخل ردیف حذف شدند.
/// تیتر کارت هم حذف شد چون صفحهٔ خانه بالای آن یک سربرگ بخش رندر میکند.
class TodaySchedulePreviewCard extends StatelessWidget {
  TodaySchedulePreviewCard({
    super.key,
    required this.snapshot,
    TodayCalendarConvergenceHelper? convergenceHelper,
  }) : convergenceHelper =
            convergenceHelper ?? TodayCalendarConvergenceHelper();

  final DayAgendaSnapshot snapshot;
  final TodayCalendarConvergenceHelper convergenceHelper;

  /// نقطهٔ خط زمانی — آیتم جاری توپر و دارای هاله، آیتم بعدی توخالی.
  Widget _dot(BuildContext context, {required bool isNow}) {
    final colors = context.colors;
    if (isNow) {
      return Container(
        height: 12,
        width: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.primary,
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.35),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      );
    }
    return Container(
      height: 12,
      width: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.card,
        border: Border.all(color: colors.textTertiary, width: 2),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required AgendaItem item,
    required bool isNow,
    required bool hasConnector,
  }) {
    final colors = context.colors;
    final tone = isNow ? colors.primary : colors.textSecondary;

    final timeParts = <String>[
      if (item.timeOfDay != null) 'ساعت ${item.timeOfDay}',
      if (isNow && item.durationMinutes != null)
        '${item.durationMinutes} دقیقه',
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ریل خط زمانی
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 6),
                _dot(context, isNow: isNow),
                if (hasConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(RitmoRadius.pill),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: RitmoSpacing.sm),

          // محتوای ردیف — خودش دکمه است
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: hasConnector ? 12 : 0),
              child: Material(
                color: isNow
                    ? colors.primary.withValues(alpha: 0.08)
                    : colors.textPrimary.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(RitmoRadius.chip),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    RitmoHaptics.tap();
                    convergenceHelper.openCalendarInContext(
                      context,
                      itemId: item.id,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isNow ? 'اکنون' : 'بعدی',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                      color: tone,
                                    ),
                                  ),
                                  if (timeParts.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      height: 3,
                                      width: 3,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.textTertiary,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        toPersianDigits(timeParts.join(' · ')),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: colors.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // P1-1ب: تا قبل از E-1 فقط روتین‌ها از اینجا تیک میخورند
                        // (مسیر امن REK)؛ مستحبات از صفحهٔ عبادت تیک میخورند.
                        if (isNow && item.domain == AgendaDomain.routine) ...[
                          const SizedBox(width: RitmoSpacing.sm),
                          Semantics(
                            button: true,
                            label: 'تکمیل برنامه',
                            child: Material(
                              color: colors.success.withValues(alpha: 0.14),
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  RitmoHaptics.confirm();
                                  convergenceHelper.completeItem(item);
                                },
                                child: SizedBox(
                                  height: 34,
                                  width: 34,
                                  child: Icon(
                                    CupertinoIcons.checkmark_alt,
                                    size: 17,
                                    color: colors.success,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: RitmoSpacing.xs),
                          Icon(
                            CupertinoIcons.chevron_left,
                            size: 13,
                            color: colors.textTertiary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.success.withValues(alpha: 0.12),
          ),
          child: Icon(
            CupertinoIcons.checkmark_seal_fill,
            size: 19,
            color: colors.success,
          ),
        ),
        const SizedBox(width: RitmoSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'مسیر امروز خلوت است',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'برنامهٔ فعالی برای این ساعت باقی نمانده است.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final current = snapshot.currentActivity;
    final next = snapshot.nextActivity;
    final topSuggestion =
        snapshot.suggestions.isNotEmpty ? snapshot.suggestions.first : null;
    final isEmpty = current == null && next == null && topSuggestion == null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoTheme.glassCardLight(
        borderRadius: RitmoRadius.cardLarge,
        color: colors.card.withValues(alpha: 0.65),
        child: Padding(
          padding: const EdgeInsets.all(RitmoSpacing.md),
          child: isEmpty
              ? _emptyState(context)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (current != null)
                      _row(
                        context,
                        item: current,
                        isNow: true,
                        hasConnector: next != null,
                      ),
                    if (next != null)
                      _row(
                        context,
                        item: next,
                        isNow: false,
                        hasConnector: false,
                      ),
                    if (topSuggestion != null) ...[
                      if (current != null || next != null)
                        const SizedBox(height: RitmoSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.goldAccent.withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(RitmoRadius.chip),
                          border: Border.all(
                            color: colors.goldAccent.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              CupertinoIcons.lightbulb_fill,
                              size: 13,
                              color: colors.goldAccent,
                            ),
                            const SizedBox(width: RitmoSpacing.sm),
                            Expanded(
                              child: Text(
                                topSuggestion.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.5,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
