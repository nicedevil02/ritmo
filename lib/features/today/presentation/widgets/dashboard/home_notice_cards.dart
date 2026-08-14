import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/models/inbox_item.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// کارت‌های اطلاع‌رسانی صفحهٔ خانه.
///
/// این ویجت‌ها کاملاً نمایشی‌اند: منطق دیده‌شدن و تمام اقدام‌ها در صفحه می‌ماند
/// و اینجا فقط با callback دریافت می‌شود (تا قابل تست و قابل استفادهٔ مجدد باشند).

/// پوستهٔ مشترک همهٔ کارت‌های اطلاع‌رسانی — تُن رنگی، حاشیه و شعاع یکدست.
class _NoticeShell extends StatelessWidget {
  const _NoticeShell({
    required this.tone,
    required this.child,
    this.onTap,
  });

  final Color tone;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(RitmoRadius.cardLarge);

    final content = Padding(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: tone.withValues(alpha: isDark ? 0.14 : 0.07),
        border: Border.all(color: tone.withValues(alpha: isDark ? 0.32 : 0.22)),
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: content,
              ),
            ),
    );
  }
}

/// ردیف سرعنوان مشترک کارت‌ها: آیکون دایره‌ای + عنوان + توضیح.
class _NoticeHeader extends StatelessWidget {
  const _NoticeHeader({
    required this.icon,
    required this.tone,
    required this.title,
    this.description,
    this.trailing,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: tone, size: 18),
        ),
        const SizedBox(width: RitmoSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  ),
              ),
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  description!,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: colors.textSecondary,
                    ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// هشدارهای بحرانی موتور هوشمند (تداخل دارویی، سقف دوز، اضافه‌بار و مانند آن).
class CriticalAlertsCard extends StatelessWidget {
  const CriticalAlertsCard({super.key, required this.alerts});

  final List<String> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final tone = colors.error;

    return _NoticeShell(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoticeHeader(
            icon: CupertinoIcons.exclamationmark_triangle_fill,
            tone: tone,
            title: l10n.criticalSystemAlerts,
          ),
          const SizedBox(height: RitmoSpacing.sm),
          for (final alert in alerts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    height: 5,
                    width: 5,
                    decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.6,
                        color: colors.textPrimary,
                        ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// یادآور ارزیابی صبحگاهی.
class CheckinReminderCard extends StatelessWidget {
  const CheckinReminderCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return _NoticeShell(
      tone: colors.primary,
      onTap: onTap,
      child: _NoticeHeader(
        icon: CupertinoIcons.sparkles,
        tone: colors.primary,
        title: l10n.checkinReminderTitle,
        description: l10n.checkinReminderDesc,
        trailing: Icon(
          CupertinoIcons.chevron_left,
          color: colors.textSecondary,
          size: 15,
        ),
      ),
    );
  }
}

/// پیشنهاد بازتاب شبانه.
class ReflectionSuggestionCard extends StatelessWidget {
  const ReflectionSuggestionCard({
    super.key,
    required this.onDismiss,
    required this.onRecord,
  });

  final VoidCallback onDismiss;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final tone = colors.sleepAccent;

    return _NoticeShell(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoticeHeader(
            icon: CupertinoIcons.moon_stars_fill,
            tone: tone,
            title: l10n.reflectionReminderTitle,
            description: l10n.reflectionReminderDesc,
          ),
          const SizedBox(height: RitmoSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.md,
                    vertical: RitmoSpacing.sm,
                  ),
                ),
                child: Text(
                  l10n.laterOrDismiss,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: RitmoSpacing.sm),
              ElevatedButton(
                onPressed: onRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tone,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.lg,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.chip),
                  ),
                ),
                child: Text(
                  l10n.yesRecord,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// پیشنهاد بازچینی میانهٔ روز وقتی برنامه عقب افتاده است.
class MidDayReplanCard extends StatelessWidget {
  const MidDayReplanCard({
    super.key,
    required this.onDismiss,
    required this.onReplan,
  });

  final VoidCallback onDismiss;
  final VoidCallback onReplan;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = colors.goldAccent;

    return _NoticeShell(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NoticeHeader(
            icon: Icons.history_toggle_off_rounded,
            tone: tone,
            title: 'برنامه امروز شما عقب افتاده است ⏳',
            description: 'آیا مایلید برنامه باقی‌مانده روز شما مجدداً چیده شود؟',
          ),
          const SizedBox(height: RitmoSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.md,
                    vertical: RitmoSpacing.sm,
                  ),
                ),
                child: const Text(
                  'انصراف',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: RitmoSpacing.sm),
              ElevatedButton(
                onPressed: onReplan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tone,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.lg,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.chip),
                  ),
                ),
                child: const Text(
                  'بازچینی برنامه',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// آخرین یادآوری‌ها و اعلان‌های خوانده‌نشدهٔ اینباکس.
class RecentInboxCard extends StatelessWidget {
  const RecentInboxCard({
    super.key,
    required this.items,
    required this.onItemTap,
    required this.onViewAll,
  });

  final List<InboxItem> items;
  final void Function(InboxItem item) onItemTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'آخرین یادآوری‌ها و اعلان‌ها 🔔',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                  ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.sm),
                minimumSize: const Size(0, 32),
              ),
              child: const Text(
                'مشاهده همه',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.sm),
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: RitmoSpacing.sm),
          _inboxRow(context, colors, items[i]),
        ],
      ],
    );
  }

  Widget _inboxRow(BuildContext context, RitmoColors colors, InboxItem item) {
    var tone = colors.primary;
    if (item.priority == InboxPriority.critical) {
      tone = colors.error;
    } else if (item.category == InboxCategory.MILESTONE) {
      tone = colors.goldAccent;
    } else if (item.category == InboxCategory.INSIGHT) {
      tone = colors.success;
    }

    final radius = BorderRadius.circular(RitmoRadius.card);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: colors.card.withValues(alpha: 0.5),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemTap(item),
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Container(
                  height: 26,
                  width: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, color: tone, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          ),
                      ),
                      if (item.body != null && item.body!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.body!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: colors.textSecondary,
                            ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_left,
                  color: colors.textSecondary,
                  size: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
