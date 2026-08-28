import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CycleHistoryList extends StatelessWidget {
  const CycleHistoryList({
    super.key,
    required this.periods,
    required this.onAddNewPeriod,
    required this.onEditPeriod,
    required this.onDeletePeriod,
  });

  final List<Map<String, dynamic>> periods;
  final VoidCallback onAddNewPeriod;
  final ValueChanged<Map<String, dynamic>> onEditPeriod;
  final ValueChanged<String> onDeletePeriod;

  String _formatIsoToJalali(String iso) {
    final dt = CycleDateContract.parseDayKey(iso);
    if (dt == null) return iso;
    final jal = Jalali.fromDateTime(dt);
    return '${PersianDigits.toFa(jal.year.toString())}/${PersianDigits.toFa(jal.month.toString().padLeft(2, '0'))}/${PersianDigits.toFa(jal.day.toString().padLeft(2, '0'))}';
  }

  int? _calculateDurationDays(String startStr, String? endStr) {
    if (endStr == null) return null;
    final startDt = CycleDateContract.parseDayKey(startStr);
    final endDt = CycleDateContract.parseDayKey(endStr);
    if (startDt == null || endDt == null) return null;
    final diff = endDt.difference(startDt).inDays + 1;
    return diff > 0 ? diff : 1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // توکن‌های جزیره نئومورفیک (منطبق با جزیره تقویم)
    final cardBg = isDark ? const Color(0xFF1B202B) : const Color(0xFFF0F3F7);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.90);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            offset: const Offset(-4, -4),
            blurRadius: 14,
            color: isDark
                ? Colors.white.withValues(alpha: 0.035)
                : Colors.white,
          ),
          BoxShadow(
            offset: const Offset(6, 8),
            blurRadius: 18,
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : const Color(0xFFCBD2DD).withValues(alpha: 0.70),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر جزیره: عنوان، تعداد دوره‌ها، و دکمه نئومورفیک افزودن دوره
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: isDark ? 0.20 : 0.12),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.clock_fill,
                      size: 16,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'تاریخچه دوره‌ها',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (periods.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${PersianDigits.toFa(periods.length.toString())} دوره',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // دکمه کپسولی افزودن دوره
              Semantics(
                button: true,
                label: 'افزودن دوره قبلی',
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    RitmoHapticsPolicy.selection();
                    onAddNewPeriod();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(
                        alpha: isDark ? 0.18 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.38),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.plus,
                          size: 13,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'افزودن دوره',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // محتوای جزیره: تایم‌لاین عمودی دوره‌ها یا استیت خالی
          if (periods.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                      ),
                      child: Icon(
                        CupertinoIcons.calendar_badge_plus,
                        size: 22,
                        color: colors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'هنوز دوره‌ای ثبت نشده است',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'برای دقت بالاتر پیش‌بینی‌ها، دوره‌های قبلی خود را ثبت کنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: periods.length,
              itemBuilder: (context, index) {
                final p = periods[index];
                final startStr = p['startDate'] as String;
                final endStr = p['endDate'] as String?;
                final isOngoing = endStr == null;
                final durationDays = _calculateDurationDays(startStr, endStr);
                final isLastItem = index == periods.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ستون تایم‌لاین عمودی اپل هلث (گره و خط اتصال)
                      SizedBox(
                        width: 22,
                        child: Column(
                          children: [
                            // گره زمانی (Timeline Node)
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isOngoing
                                    ? colors.primary
                                    : colors.error.withValues(alpha: 0.88),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isOngoing ? colors.primary : colors.error)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // خط عمودی اتصال به رویداد بعدی
                            if (!isLastItem)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : colors.border.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 8),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // کارت محتوای دوره (Inner Soft Tile)
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                            bottom: isLastItem ? 0 : 10,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : colors.border.withValues(alpha: 0.35),
                              width: 0.9,
                            ),
                          ),
                          child: Row(
                            children: [
                              // اطلاعات دوره و تاریخ‌ها
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          isOngoing
                                              ? 'دوره فعال بدنی'
                                              : 'دوره قاعدگی',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // بج وضعیت یا مدت زمان دوره
                                        if (isOngoing)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.primary.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'در حال جریان',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: colors.primary,
                                              ),
                                            ),
                                          )
                                        else if (durationDays != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.error.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${PersianDigits.toFa(durationDays.toString())} روز',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: colors.error,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isOngoing
                                          ? 'شروع: ${_formatIsoToJalali(startStr)}'
                                          : '${_formatIsoToJalali(startStr)}  تا  ${_formatIsoToJalali(endStr!)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // دکمه‌های کنترلی گرد (ویرایش و حذف)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // دکمه ویرایش
                                  InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      RitmoHapticsPolicy.selection();
                                      onEditPeriod(p);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : Colors.black.withValues(alpha: 0.03),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.pencil,
                                        color: colors.primary,
                                        size: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // دکمه حذف
                                  InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      RitmoHapticsPolicy.warning();
                                      onDeletePeriod(p['id'] as String);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : Colors.black.withValues(alpha: 0.03),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.trash,
                                        color: colors.error.withValues(alpha: 0.8),
                                        size: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
