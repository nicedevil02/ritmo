import 'package:ritmo/core/domain/agenda/agenda_item.dart';

/// ورودیهای تصمیم «اقدام بعدی» صفحهٔ اصلی — خالص، بدون وابستگی به فلاتر.
///
/// همهٔ فیلدها مقادیر ازپیشمحاسبهشده هستند تا این کلاس بدون DB/سرویس
/// قابلتست واحد باشد.
class HomeFocusInput {
  const HomeFocusInput({
    required this.now,
    this.hasActiveTimer = false,
    this.medicalCriticalCount = 0,
    this.pendingMedDoses = 0,
    this.medicineModuleEnabled = false,
    this.agendaItems = const [],
    this.fallbackTasksPending = false,
    this.needCheckin = false,
  });

  /// لحظهٔ ارزیابی (برای تشخیص upcoming/overdue).
  final DateTime now;

  /// آیا تایمری در حال اجراست؟
  final bool hasActiveTimer;

  /// تعداد هشدارهای بحرانی دارویی (تداخل، نقض حداقل فاصله، عبور از سقف دوز،
  /// داروی حیاتی). سیمکشی محاسبهٔ واقعیاش فاز بعدی است — فعلاً صفر پاس میشود.
  final int medicalCriticalCount;

  /// دوزهای باقیماندهٔ امروز (تخمین کنترلر از occurrenceهای امروز).
  final int pendingMedDoses;

  final bool medicineModuleEnabled;

  /// آیتمهای امروز از DayAgendaService (همهٔ دامنهها).
  final List<AgendaItem> agendaItems;

  /// آیا در timeline روتینی (پیش از لود P1) کار انجامنشده هست؟
  final bool fallbackTasksPending;

  final bool needCheckin;
}

/// سطوح اولویت کارت «اقدام بعدی» — منطبق بر جدول ۹ سطحی سند v2
/// (سطوح medicalCritical..emptyState؛ سطوح آینده بدون شکستن سازگاری اضافه میشوند).
enum HomeFocusLevel {
  /// بحران دارویی — تنها سطحی که تایمر فعال را کنار میزند (قانون سند v2).
  medicalCritical,
  activeTimer,
  medicalDue,
  agendaItem,

  /// fallback روتینی تا قبل از رسیدن Agenda (لود P1).
  agendaFallback,
  morningCheckIn,
  emptyState,
}

class HomeFocusDecision {
  const HomeFocusDecision(
    this.level, {
    this.agendaItem,
    this.isOverdue = false,
    this.isCurrentActive = false,
    this.previousItem,
    this.nextItem,
  });

  final HomeFocusLevel level;

  /// آیتم منتخب — فقط وقتی [level] برابر [HomeFocusLevel.agendaItem] است.
  final AgendaItem? agendaItem;

  /// true یعنی آیتم منتخب از ساعتش گذشته (هیچ آیتم آیندهای نبود).
  final bool isOverdue;

  /// true یعنی کاربر دقیقاً در بازهٔ زمانی این کار قرار دارد (اکنون / در حال اجرا).
  final bool isCurrentActive;

  /// کار قبلی برای نمایش در نوار زمینه
  final AgendaItem? previousItem;

  /// کار بعدی برای نمایش در نوار زمینه
  final AgendaItem? nextItem;
}

/// رتبهبند خالص «اقدام بعدی». بدون state، بدون side-effect، کاملاً قطعی.
class HomeFocusRanker {
  const HomeFocusRanker._();

  static int? _minutesOf(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static HomeFocusDecision decide(HomeFocusInput input) {
    // ── سطح ۱: بحران دارویی — تنها چیزی که تایمر فعال را کنار میزند ──
    if (input.medicineModuleEnabled && input.medicalCriticalCount > 0) {
      return const HomeFocusDecision(HomeFocusLevel.medicalCritical);
    }

    // ── سطح ۲: تایمر فعال ──
    if (input.hasActiveTimer) {
      return const HomeFocusDecision(HomeFocusLevel.activeTimer);
    }

    // ── سطح ۳: دوزهای باقیماندهٔ واقعی ──
    if (input.medicineModuleEnabled && input.pendingMedDoses > 0) {
      return const HomeFocusDecision(HomeFocusLevel.medicalDue);
    }

    // ── سطح ۴: نزدیکترین آیتم زماندارِ انجامنشده از Agenda ──
    final nowMinutes = input.now.hour * 60 + input.now.minute;
    final allTimedItems = input.agendaItems
        .where((i) =>
            i.hasValidTimeOfDay &&
            i.domain != AgendaDomain.worshipDebt)
        .toList()
      ..sort((a, b) => a.timeOfDay!.compareTo(b.timeOfDay!));

    if (allTimedItems.isNotEmpty) {
      // الف) جستجوی کار جاری (اکنون در حال اجرا):
      AgendaItem? currentActive;
      AgendaItem? previousItem;
      AgendaItem? nextItem;

      for (int i = 0; i < allTimedItems.length; i++) {
        final item = allTimedItems[i];
        final start = _minutesOf(item.timeOfDay) ?? 0;
        final duration = (item.durationMinutes != null && item.durationMinutes! > 0)
            ? item.durationMinutes!
            : 30;
        final end = start + duration;

        if (nowMinutes >= start && nowMinutes < end) {
          if (!item.isCompleted) {
            currentActive = item;
            if (i > 0) {
              previousItem = allTimedItems[i - 1];
            }
            for (int j = i + 1; j < allTimedItems.length; j++) {
              if (!allTimedItems[j].isCompleted) {
                nextItem = allTimedItems[j];
                break;
              }
            }
            break;
          }
        }
      }

      if (currentActive != null) {
        return HomeFocusDecision(
          HomeFocusLevel.agendaItem,
          agendaItem: currentActive,
          isCurrentActive: true,
          previousItem: previousItem,
          nextItem: nextItem,
        );
      }

      // ب) جستجوی نزدیک‌ترین اقدام بعدی در پیش‌رو:
      final pendingCandidates = allTimedItems.where((i) => !i.isCompleted).toList();
      if (pendingCandidates.isNotEmpty) {
        for (int i = 0; i < pendingCandidates.length; i++) {
          final item = pendingCandidates[i];
          final start = _minutesOf(item.timeOfDay);
          if (start != null && start >= nowMinutes) {
            final itemIdx = allTimedItems.indexOf(item);
            if (itemIdx > 0) {
              previousItem = allTimedItems[itemIdx - 1];
            }
            if (i + 1 < pendingCandidates.length) {
              nextItem = pendingCandidates[i + 1];
            }
            return HomeFocusDecision(
              HomeFocusLevel.agendaItem,
              agendaItem: item,
              isCurrentActive: false,
              previousItem: previousItem,
              nextItem: nextItem,
            );
          }
        }

        // ج) همه گذشته‌اند ⇒ اولین (قدیمی‌ترین) عقب‌افتاده
        return HomeFocusDecision(
          HomeFocusLevel.agendaItem,
          agendaItem: pendingCandidates.first,
          isOverdue: true,
        );
      }
    }

    // ── سطح ۵: fallback روتینی (پنجرهٔ قبل از لود P1) ──
    if (input.fallbackTasksPending) {
      return const HomeFocusDecision(HomeFocusLevel.agendaFallback);
    }

    // ── سطح ۶: چکاین صبحگاهی ──
    if (input.needCheckin) {
      return const HomeFocusDecision(HomeFocusLevel.morningCheckIn);
    }

    // ── سطح ۷: حالت خالی صادقانه ──
    return const HomeFocusDecision(HomeFocusLevel.emptyState);
  }
}
