// lib/features/supplementary_sports/movement/presentation/widgets/movement_week_timeline.dart
//
// تایم‌لاین فعالیت‌های هفته. قبلاً داخل ss_movement_tab_screen.dart بود.

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_budget.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/movement_datetime_field.dart';

/// بازگرداندن یک فعالیت حذف‌شده (دکمهٔ «بازگردانی» در اسنک‌بار).
typedef MovementEventRestore = Future<void> Function(MovementEvent event);

class MovementWeekTimeline extends StatelessWidget {
  const MovementWeekTimeline({
    super.key,
    required this.snapshot,
    required this.onChanged,
    required this.onRestore,
  });

  final MovementBudgetSnapshot? snapshot;

  /// پس از هر تغییر واقعی در دیتابیس صدا زده می‌شود.
  final VoidCallback onChanged;
  final MovementEventRestore onRestore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final events = snapshot?.events ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'فعالیت‌های این هفته',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: RitmoSpacing.md),
        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(RitmoSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Icon(CupertinoIcons.calendar, size: 28, color: colors.textTertiary),
                const SizedBox(height: RitmoSpacing.sm),
                Text(
                  'این هفته هنوز فعالیتی ثبت نشده',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: RitmoSpacing.xs),
                Text(
                  'هر چه را که انجام داده‌ای ثبت کن — حتی ۱۵ دقیقه پیاده‌روی.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 11.5,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          )
        else
          ..._buildGroupedRows(context, events),
      ],
    );
  }

  /// گروه‌بندی براساس روز، تازه‌ترین بالا. قبلاً هیچ زمانی نشان داده نمی‌شد
  /// و دو جلسهٔ یک روز از هم قابل تشخیص نبودند.
  List<Widget> _buildGroupedRows(BuildContext context, List<MovementEvent> events) {
    final colors = context.colors;
    final sorted = [...events]..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    final widgets = <Widget>[];
    String? currentDayKey;

    for (final event in sorted) {
      final dt = DateTime.fromMillisecondsSinceEpoch(event.loggedAt);
      final dayKey = '${dt.year}-${dt.month}-${dt.day}';

      if (dayKey != currentDayKey) {
        currentDayKey = dayKey;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(
              top: widgets.isEmpty ? 0 : RitmoSpacing.md,
              bottom: RitmoSpacing.sm,
            ),
            child: Text(
              movementRelativeDayLabel(dt),
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.textSecondary,
              ),
            ),
          ),
        );
      }

      widgets.add(_buildRow(context, event, dt));
    }

    return widgets;
  }

  Widget _buildRow(BuildContext context, MovementEvent event, DateTime loggedAt) {
    final kind = snapshot?.kindsByCode[event.kindCode];
    final title = kind == null ? event.kindCode : '${kind.emoji} ${kind.titleFa}';

    // رکوردهای متعلق به جلسهٔ بدنسازی از اینجا حذف‌شدنی نیستند؛
    // قبلاً سوایپ می‌شدند و مخزن StateError پرتاب می‌کرد.
    final isLocked = event.sourceModule != 'MOVEMENT';

    final card = _TimelineCard(
      title: title,
      durationMinutes: event.durationMinutes,
      metMinutes: event.metMinutes,
      loggedAt: loggedAt,
      isLocked: isLocked,
    );

    if (isLocked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
      child: Dismissible(
        key: Key(event.id),
        direction: DismissDirection.endToStart,
        // بدون دیالوگ تأیید: حذف فوری است ولی با «بازگردانی» قابل جبران.
        onDismissed: (_) => _handleDismiss(context, event),
        background: Container(
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsetsDirectional.only(start: RitmoSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.error.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(RitmoRadius.card),
          ),
          child: const Icon(CupertinoIcons.trash, color: Colors.white, size: 20),
        ),
        child: card,
      ),
    );
  }

  Future<void> _handleDismiss(BuildContext context, MovementEvent event) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await MovementRepository.instance.deleteEvent(event.id);
    } on StateError {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'این رکورد متعلق به جلسهٔ بدنسازی است و از همانجا حذف می‌شود.',
            style: TextStyle(fontFamily: 'Vazirmatn'),
          ),
        ),
      );
      onChanged();
      return;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'حذف نشد: $e',
            style: const TextStyle(fontFamily: 'Vazirmatn'),
          ),
        ),
      );
      onChanged();
      return;
    }

    onChanged();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'فعالیت حذف شد',
          style: TextStyle(fontFamily: 'Vazirmatn'),
        ),
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: () => unawaited(onRestore(event)),
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.title,
    required this.durationMinutes,
    required this.metMinutes,
    required this.loggedAt,
    required this.isLocked,
  });

  final String title;
  final int durationMinutes;
  final double metMinutes;
  final DateTime loggedAt;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      label: isLocked
          ? '$title، متعلق به جلسهٔ بدنسازی'
          : '$title، برای حذف به چپ بکش',
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.lg,
          vertical: RitmoSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${durationMinutes.toPersianDigits()} دقیقه · ${movementClockLabel(loggedAt)}',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isLocked)
              Tooltip(
                message: 'از بخش بدنسازی قابل ویرایش است',
                child: Icon(CupertinoIcons.lock_fill, size: 14, color: colors.textTertiary),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.sm,
                  vertical: RitmoSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: context.modules.sports.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(RitmoRadius.badge),
                ),
                child: Text(
                  'بار ${metMinutes.round().toPersianDigits()}',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: context.modules.sports,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
