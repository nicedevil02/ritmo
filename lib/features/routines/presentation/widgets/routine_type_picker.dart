import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

/// Descriptor for routine execution model in UI
class RoutineTypeOption {
  const RoutineTypeOption({
    required this.type,
    required this.titleFa,
    required this.subtitleFa,
    required this.icon,
    required this.badgeFa,
  });

  final RoutineType type;
  final String titleFa;
  final String subtitleFa;
  final IconData icon;
  final String badgeFa;
}

/// Selector widget for choosing the routine execution model (RoutineType)
/// adhering to Ritmo Aurora glassmorphism design system.
class RoutineTypePicker extends StatelessWidget {
  const RoutineTypePicker({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  final RoutineType selectedType;
  final ValueChanged<RoutineType> onTypeSelected;

  static const List<RoutineTypeOption> options = [
    RoutineTypeOption(
      type: RoutineType.timeBased,
      titleFa: 'زمان‌محور',
      subtitleFa: 'ساعت مشخص روزانه و اجرا با تایمر',
      icon: Icons.alarm_rounded,
      badgeFa: 'پیش‌فرض',
    ),
    RoutineTypeOption(
      type: RoutineType.countBased,
      titleFa: 'شمارشی',
      subtitleFa: 'رسیدن به هدف عددی (مثل ۸ لیوان آب یا ۵۰ صفحه)',
      icon: Icons.tag_rounded,
      badgeFa: 'هدفمند',
    ),
    RoutineTypeOption(
      type: RoutineType.progressive,
      titleFa: 'پیش‌رونده',
      subtitleFa: 'شروع آرام و افزایش خودکار سختی (عادات اتمی)',
      icon: Icons.trending_up_rounded,
      badgeFa: 'تدریجی',
    ),
    RoutineTypeOption(
      type: RoutineType.intervalBased,
      titleFa: 'فاصله‌ای',
      subtitleFa: 'تکرار منظم هر چند ساعت یک‌بار (دارو یا استراحت)',
      icon: Icons.timelapse_rounded,
      badgeFa: 'دوره‌ای',
    ),
    RoutineTypeOption(
      type: RoutineType.dependent,
      titleFa: 'زنجیره‌ای',
      subtitleFa: 'اجرای خودکار بلافاصله پس از روتین دیگر',
      icon: Icons.link_rounded,
      badgeFa: 'وابسته',
    ),
    RoutineTypeOption(
      type: RoutineType.asNeeded,
      titleFa: 'برحسب نیاز',
      subtitleFa: 'ثبت آزاد در هر زمان بدون ساعت اجباری (PRN)',
      icon: Icons.bolt_rounded,
      badgeFa: 'آزاد',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: colors.primary),
              const SizedBox(width: RitmoSpacing.sm),
              Text(
                'مدل اجرای روتین',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'نحوهٔ یادآوری، ردیابی و تکمیل این روتین را انتخاب کنید:',
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: RitmoSpacing.md),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(height: RitmoSpacing.sm),
            itemBuilder: (context, index) {
              final opt = options[index];
              final isSelected = selectedType == opt.type;

              return InkWell(
                onTap: () {
                  RitmoHaptics.selection();
                  onTypeSelected(opt.type);
                },
                borderRadius: BorderRadius.circular(RitmoRadius.card),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary.withValues(alpha: 0.12)
                        : colors.card.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.4),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? colors.primary.withValues(alpha: 0.2)
                              : colors.surface,
                        ),
                        child: Icon(
                          opt.icon,
                          size: 20,
                          color: isSelected ? colors.primary : colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: RitmoSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  opt.titleFa,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? colors.primary : colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: RitmoSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary.withValues(alpha: 0.15)
                                        : colors.border.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                                  ),
                                  child: Text(
                                    opt.badgeFa,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSelected ? colors.primary : colors.textTertiary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              opt.subtitleFa,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Radio<RoutineType>(
                        value: opt.type,
                        groupValue: selectedType,
                        activeColor: colors.primary,
                        onChanged: (val) {
                          if (val != null) {
                            RitmoHaptics.selection();
                            onTypeSelected(val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
