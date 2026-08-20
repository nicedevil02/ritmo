import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/theme/ritmo_colors.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/health/data/pregnancy_helpers.dart';

class PregStep2Dates extends StatelessWidget {
  const PregStep2Dates({
    super.key,
    required this.data,
    required this.onDataChanged,
    required this.onNext,
    required this.colors,
    required this.isDark,
  });

  final PregnancyOnboardingData data;
  final ValueChanged<PregnancyOnboardingData> onDataChanged;
  final VoidCallback onNext;
  final RitmoColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('preg_step_2_dates'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مبنای محاسبهٔ تاریخ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'برای اینکه هفتهٔ بارداری و زمان تقریبی زایمان را بدانیم، یکی از این سه روش را انتخاب کن.',
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Option 1: LMP
          _buildMethodCard(
            context: context,
            source: PregnancyEddSource.lmp,
            icon: CupertinoIcons.calendar_today,
            title: 'اولین روز آخرین پریودم را می‌دانم',
            subtitle: 'بر اساس تاریخ شروع آخرین قاعدگی (LMP)',
          ),
          const SizedBox(height: 12),

          // Option 2: Doctor EDD
          _buildMethodCard(
            context: context,
            source: PregnancyEddSource.doctorEdd,
            icon: CupertinoIcons.person_crop_circle_badge_checkmark,
            title: 'تاریخ زایمان را پزشک گفته',
            subtitle: 'تاریخ تخمینی زایمان که در پروندهٔ پزشکی ثبت شده',
          ),
          const SizedBox(height: 12),

          // Option 3: Ultrasound
          _buildMethodCard(
            context: context,
            source: PregnancyEddSource.ultrasound,
            icon: CupertinoIcons.waveform_path_ecg,
            title: 'جواب سونوگرافی دارم',
            subtitle: 'بر اساس سن جنین در تاریخ انجام سونوگرافی',
          ),
          const SizedBox(height: 20),

          // Sub-controls based on chosen source
          if (data.eddSource == PregnancyEddSource.lmp)
            _buildLmpSection(context)
          else if (data.eddSource == PregnancyEddSource.doctorEdd)
            _buildDoctorEddSection(context)
          else if (data.eddSource == PregnancyEddSource.ultrasound)
            _buildUltrasoundSection(context),

          const SizedBox(height: 20),

          // Live feedback banner or error banner
          _buildLiveFeedbackBanner(context),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required BuildContext context,
    required PregnancyEddSource source,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = data.eddSource == source;
    final primaryColor = colors.primary;

    return InkWell(
      onTap: () {
        if (data.eddSource != source) {
          final now = CycleClock.now;
          if (source == PregnancyEddSource.lmp) {
            final effectiveLmp = data.lmpDate ?? now.subtract(const Duration(days: 56));
            final effectiveDue = PregnancyDateEngine.dueDateFromLmp(effectiveLmp);
            onDataChanged(data.copyWith(
              eddSource: source,
              lmpDate: effectiveLmp,
              dueDate: effectiveDue,
            ));
          } else if (source == PregnancyEddSource.doctorEdd) {
            final effectiveDue = data.dueDate ?? now.add(const Duration(days: 224));
            final effectiveLmp = PregnancyDateEngine.lmpFromDueDate(effectiveDue);
            onDataChanged(data.copyWith(
              eddSource: source,
              lmpDate: effectiveLmp,
              dueDate: effectiveDue,
            ));
          } else if (source == PregnancyEddSource.ultrasound) {
            final scanDate = data.scanDate ?? now.subtract(const Duration(days: 7));
            final scanWeeks = data.scanWeeks > 0 ? data.scanWeeks : 8;
            final scanDays = data.scanDays;
            final effectiveLmp = PregnancyDateEngine.lmpFromUltrasound(
              scanDate: scanDate,
              weeksAtScan: scanWeeks,
              daysAtScan: scanDays,
            );
            final effectiveDue = PregnancyDateEngine.dueDateFromLmp(effectiveLmp);
            onDataChanged(data.copyWith(
              eddSource: source,
              scanDate: scanDate,
              scanWeeks: scanWeeks,
              scanDays: scanDays,
              lmpDate: effectiveLmp,
              dueDate: effectiveDue,
            ));
          }
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : colors.border.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.2)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? primaryColor : colors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? primaryColor : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                color: primaryColor,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLmpSection(BuildContext context) {
    final lmp = data.lmpDate ?? CycleClock.now.subtract(const Duration(days: 56));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تاریخ شروع آخرین قاعدگی (LMP):',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _buildDatePickerTile(
          context: context,
          date: lmp,
          onTap: () => _pickLmpDate(context, lmp),
        ),
      ],
    );
  }

  Widget _buildDoctorEddSection(BuildContext context) {
    final due = data.dueDate ?? CycleClock.now.add(const Duration(days: 224));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تاریخ تخمینی زایمان (EDD):',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _buildDatePickerTile(
          context: context,
          date: due,
          onTap: () => _pickDoctorDueDate(context, due),
        ),
      ],
    );
  }

  Widget _buildUltrasoundSection(BuildContext context) {
    final scanDate = data.scanDate ?? CycleClock.now.subtract(const Duration(days: 7));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تاریخ انجام سونوگرافی:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _buildDatePickerTile(
          context: context,
          date: scanDate,
          onTap: () => _pickScanDate(context, scanDate),
        ),
        const SizedBox(height: 16),
        Text(
          'سن جنین در تاریخ سونوگرافی:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Weeks selector
            Expanded(
              child: _buildNumberCounter(
                label: 'هفته',
                value: data.scanWeeks,
                min: 4,
                max: 42,
                onChanged: (w) {
                  final newLmp = PregnancyDateEngine.lmpFromUltrasound(
                    scanDate: scanDate,
                    weeksAtScan: w,
                    daysAtScan: data.scanDays,
                  );
                  final newDue = PregnancyDateEngine.dueDateFromLmp(newLmp);
                  onDataChanged(data.copyWith(
                    scanWeeks: w,
                    lmpDate: newLmp,
                    dueDate: newDue,
                  ));
                },
              ),
            ),
            const SizedBox(width: 12),
            // Days selector
            Expanded(
              child: _buildNumberCounter(
                label: 'روز',
                value: data.scanDays,
                min: 0,
                max: 6,
                onChanged: (d) {
                  final newLmp = PregnancyDateEngine.lmpFromUltrasound(
                    scanDate: scanDate,
                    weeksAtScan: data.scanWeeks,
                    daysAtScan: d,
                  );
                  final newDue = PregnancyDateEngine.dueDateFromLmp(newLmp);
                  onDataChanged(data.copyWith(
                    scanDays: d,
                    lmpDate: newLmp,
                    dueDate: newDue,
                  ));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatePickerTile({
    required BuildContext context,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final primaryColor = colors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.calendar,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _formatJalaliDate(date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            Text(
              'تغییر تاریخ',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberCounter({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final primaryColor = colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.minus_circle, size: 24),
            color: value > min ? primaryColor : colors.textSecondary.withValues(alpha: 0.3),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Column(
            children: [
              Text(
                PersianDigits.toFa(value.toString()),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.plus_circle, size: 24),
            color: value < max ? primaryColor : colors.textSecondary.withValues(alpha: 0.3),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveFeedbackBanner(BuildContext context) {
    if (data.lmpDate == null || data.dueDate == null) {
      return const SizedBox.shrink();
    }

    final validation = PregnancyDateEngine.validatePregnancyDates(
      lmp: data.lmpDate!,
      edd: data.dueDate!,
    );

    if (!validation.isValid) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                validation.errorMessageFa ?? 'تاریخ واردشده معتبر نیست.',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final age = PregnancyDateEngine.calculateCurrentGestation(lmp: data.lmpDate!);
    final remainingDays = PregnancyDateEngine.calculateRemainingDays(edd: data.dueDate!);
    final formattedAge = PregnancyDateEngine.formatGestationalAgeFa(age, unit: data.ageUnit);
    final countdownStr = PregnancyHelpers.formatHumanCountdown(remainingDays);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.sparkles, color: colors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'یعنی الان $formattedAge — حدود $countdownStr مانده. درست است؟',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.primary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLmpDate(BuildContext context, DateTime initialDate) async {
    final today = CycleClock.now;
    final threeHundredDaysAgo = today.subtract(const Duration(days: 300));

    final picked = await RitmoDatePicker.showJalali(
      context: context,
      initialDate: Jalali.fromDateTime(initialDate),
      firstDate: Jalali.fromDateTime(threeHundredDaysAgo),
      lastDate: Jalali.fromDateTime(today),
    );

    if (picked != null) {
      final cleanPicked = CycleDateContract.cleanDate(picked.toDateTime());
      final cleanDue = PregnancyDateEngine.dueDateFromLmp(cleanPicked);
      onDataChanged(data.copyWith(
        lmpDate: cleanPicked,
        dueDate: cleanDue,
      ));
    }
  }

  Future<void> _pickDoctorDueDate(BuildContext context, DateTime initialDate) async {
    final today = CycleClock.now;
    final threeHundredDaysLater = today.add(const Duration(days: 300));

    final picked = await RitmoDatePicker.showJalali(
      context: context,
      initialDate: Jalali.fromDateTime(initialDate),
      firstDate: Jalali.fromDateTime(today),
      lastDate: Jalali.fromDateTime(threeHundredDaysLater),
    );

    if (picked != null) {
      final cleanPicked = CycleDateContract.cleanDate(picked.toDateTime());
      final cleanLmp = PregnancyDateEngine.lmpFromDueDate(cleanPicked);
      onDataChanged(data.copyWith(
        dueDate: cleanPicked,
        lmpDate: cleanLmp,
      ));
    }
  }

  Future<void> _pickScanDate(BuildContext context, DateTime initialDate) async {
    final today = CycleClock.now;
    final threeHundredDaysAgo = today.subtract(const Duration(days: 300));

    final picked = await RitmoDatePicker.showJalali(
      context: context,
      initialDate: Jalali.fromDateTime(initialDate),
      firstDate: Jalali.fromDateTime(threeHundredDaysAgo),
      lastDate: Jalali.fromDateTime(today),
    );

    if (picked != null) {
      final cleanPicked = CycleDateContract.cleanDate(picked.toDateTime());
      final cleanLmp = PregnancyDateEngine.lmpFromUltrasound(
        scanDate: cleanPicked,
        weeksAtScan: data.scanWeeks,
        daysAtScan: data.scanDays,
      );
      final cleanDue = PregnancyDateEngine.dueDateFromLmp(cleanLmp);
      onDataChanged(data.copyWith(
        scanDate: cleanPicked,
        lmpDate: cleanLmp,
        dueDate: cleanDue,
      ));
    }
  }

  String _formatJalaliDate(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    final dayStr = RitmoNumber.fa(j.day.toString());
    final yearStr = RitmoNumber.fa(j.year.toString());
    return '$dayStr ${_monthNameFa(j.month)} $yearStr';
  }

  String _monthNameFa(int m) {
    const months = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    if (m >= 1 && m <= 12) return months[m - 1];
    return '';
  }
}
