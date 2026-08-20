import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/theme/ritmo_colors.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';

class PregStep5Confirm extends StatelessWidget {
  const PregStep5Confirm({
    super.key,
    required this.data,
    required this.onSave,
    required this.onBack,
    this.isSaving = false,
    this.isEditMode = false,
    required this.colors,
    required this.isDark,
  });

  final PregnancyOnboardingData data;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final bool isSaving;
  final bool isEditMode;
  final RitmoColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primaryColor = colors.primary;
    final now = CycleClock.now;
    final effectiveLmp = data.lmpDate ?? now.subtract(const Duration(days: 56));
    final effectiveDue = data.dueDate ?? PregnancyDateEngine.dueDateFromLmp(effectiveLmp);
    final age = PregnancyDateEngine.calculateCurrentGestation(lmp: effectiveLmp);
    final formattedAge = PregnancyDateEngine.formatGestationalAgeFa(age, unit: data.ageUnit);

    return SingleChildScrollView(
      key: const ValueKey('preg_step_5_confirm'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditMode ? 'بازبینی و ذخیرهٔ تغییرات' : 'تأیید و راه‌اندازی بارداری',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'لطفاً خلاصهٔ اطلاعات تنظیم‌شده را بررسی کنید. با فشردن دکمهٔ ثبت، حالت بارداری فعال می‌شود.',
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  label: 'سن بارداری امروز:',
                  value: formattedAge,
                  isHighlighted: true,
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  label: 'تاریخ تقریبی زایمان:',
                  value: _formatJalaliDate(effectiveDue),
                  isHighlighted: true,
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  label: 'مبنای محاسبه:',
                  value: _formatEddSource(data.eddSource),
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  label: 'لحن همراهی:',
                  value: data.tone == PregnancyTone.warm ? 'گرم و صمیمی' : 'آرام و ساده',
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  label: 'پیش‌بینی پریود:',
                  value: data.pauseCyclePredictions ? 'متوقف می‌شود' : 'فعال می‌ماند',
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  label: 'وضعیت عبادات:',
                  value: data.suspendWorship ? 'تعلیق می‌شود' : 'دست نمی‌خورد',
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  label: 'قفل ورود:',
                  value: data.lockEnabled ? 'روشن' : 'خاموش',
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  label: 'پنهان‌سازی از صفحهٔ امروز:',
                  value: data.hideFromDashboard ? 'روشن' : 'خاموش',
                ),
                const Divider(height: 20),
                _buildSummaryRow(
                  label: 'پوشش متن اعلان‌ها:',
                  value: data.maskNotifications ? 'روشن' : 'خاموش',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isSaving ? null : onBack,
                  child: const Text('بازگشت', style: TextStyle()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: isSaving ? null : onSave,
                  child: isSaving
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : Text(
                          isEditMode ? 'ذخیرهٔ تغییرات' : 'فعال‌سازی حالت بارداری',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
              color: isHighlighted ? colors.primary : colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _formatEddSource(PregnancyEddSource source) {
    switch (source) {
      case PregnancyEddSource.lmp:
        return 'آخرین پریود';
      case PregnancyEddSource.doctorEdd:
        return 'نظر پزشک';
      case PregnancyEddSource.ultrasound:
        return 'سونوگرافی';
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
