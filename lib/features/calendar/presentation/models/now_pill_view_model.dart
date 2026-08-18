import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/models/duration_bounds.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/relative_time_formatter.dart';

class NowPillViewModel {
  const NowPillViewModel({
    required this.isVisible,
    required this.isCurrent,
    this.targetItem,
    required this.statusLabel,
    required this.timeLabel,
    this.nextItemTitle,
    this.remainingMinutesCurrent,
    this.isOverdue = false,
    this.isToday = true,
  });

  final bool isVisible;
  final bool isCurrent;
  final AgendaItem? targetItem;
  final String statusLabel;
  final String timeLabel;
  final String? nextItemTitle;
  final int? remainingMinutesCurrent;
  final bool isOverdue;
  final bool isToday;

  const NowPillViewModel.hidden()
      : isVisible = false,
        isCurrent = false,
        targetItem = null,
        statusLabel = '',
        timeLabel = '',
        nextItemTitle = null,
        remainingMinutesCurrent = null,
        isOverdue = false,
        isToday = true;

  factory NowPillViewModel.fromSnapshot(
    DayAgendaSnapshot? snapshot, {
    required DateTime now,
    bool isToday = true,
    DateTime? selectedDate,
  }) {
    if (snapshot == null) {
      return const NowPillViewModel.hidden();
    }

    final targetDate = selectedDate ?? now;
    final nowMidnight = DateTime(now.year, now.month, now.day);
    final targetMidnight = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final isPastDay = targetMidnight.isBefore(nowMidnight);
    final isFutureDay = targetMidnight.isAfter(nowMidnight);

    // Past Day Mode
    if (isPastDay) {
      final total = snapshot.items.length;
      final done = snapshot.completedCount;
      if (total == 0) return const NowPillViewModel.hidden();

      return NowPillViewModel(
        isVisible: true,
        isCurrent: false,
        targetItem: null,
        statusLabel: 'REVIEW',
        timeLabel: '${toPersianDigits(done)} از ${toPersianDigits(total)} انجام شد',
        isToday: false,
      );
    }

    // Future Day Mode
    if (isFutureDay) {
      final total = snapshot.items.length;
      if (total == 0) return const NowPillViewModel.hidden();

      final firstItem = snapshot.items.firstWhere(
        (i) => i.timeOfDay != null,
        orElse: () => snapshot.items.first,
      );

      final firstTime = firstItem.timeOfDay;
      final firstTimeStr = firstTime != null ? toPersianDigits(firstTime) : '';
      final label = firstTimeStr.isNotEmpty
          ? '${toPersianDigits(total)} برنامه · اولین: $firstTimeStr'
          : '${toPersianDigits(total)} برنامه';

      return NowPillViewModel(
        isVisible: true,
        isCurrent: false,
        targetItem: firstItem,
        statusLabel: 'SUMMARY',
        timeLabel: label,
        isToday: false,
      );
    }

    // Today Mode (isToday == true)
    final current = snapshot.currentActivity;
    final next = snapshot.nextActivity;

    if (current != null) {
      final startDt = _resolveItemStart(current);
      final durMinutes = DurationBounds.sanitize(current.durationMinutes);
      final endDt = startDt?.add(Duration(minutes: durMinutes));
      final remainingMins = (endDt != null && endDt.isAfter(now))
          ? endDt.difference(now).inMinutes.clamp(1, durMinutes)
          : durMinutes;

      final remStr = '${toPersianDigits(remainingMins.toString())} دقیقه باقی‌مانده';

      return NowPillViewModel(
        isVisible: true,
        isCurrent: true,
        targetItem: current,
        statusLabel: 'NOW',
        timeLabel: remStr,
        nextItemTitle: next?.title,
        remainingMinutesCurrent: remainingMins,
        isToday: true,
      );
    }

    if (next != null) {
      final itemTargetTime = _resolveItemStart(next);
      if (itemTargetTime == null) {
        return const NowPillViewModel.hidden();
      }

      final isOverdue = itemTargetTime.isBefore(now) && !next.isCompleted;
      final relativeTimeStr = RelativeTimeFormatter.untilFa(itemTargetTime, now: now);

      return NowPillViewModel(
        isVisible: true,
        isCurrent: false,
        targetItem: next,
        statusLabel: 'NEXT',
        timeLabel: relativeTimeStr,
        nextItemTitle: null,
        remainingMinutesCurrent: null,
        isOverdue: isOverdue,
        isToday: true,
      );
    }

    // No current or next activity left today
    if (snapshot.completedCount > 0 && snapshot.remainingCount == 0) {
      return const NowPillViewModel(
        isVisible: true,
        isCurrent: false,
        targetItem: null,
        statusLabel: 'DONE',
        timeLabel: 'برنامه‌های امروز تمام شد 🌙',
        isToday: true,
      );
    }

    return const NowPillViewModel.hidden();
  }

  static DateTime? _resolveItemStart(AgendaItem item) {
    final date = DateTime.tryParse(item.dateStr);
    if (date == null) return null;
    final timeStr = item.timeOfDay;
    if (timeStr == null || timeStr.isEmpty) return null;

    final parts = timeStr.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;

    return DateTime(date.year, date.month, date.day, h, m);
  }
}
