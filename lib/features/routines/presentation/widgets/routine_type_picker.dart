import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// Descriptor for routine execution model in UI
class RoutineTypeOption {
  const RoutineTypeOption({
    required this.type,
    this.itemType = 'ROUTINE',
    required this.titleFa,
    required this.subtitleFa,
    required this.icon,
    required this.badgeFa,
  });

  final RoutineType type;
  final String itemType;
  final String titleFa;
  final String subtitleFa;
  final IconData icon;
  final String badgeFa;
}

/// Dropdown selector widget for choosing the routine execution model (RoutineType / Reminder)
/// adhering to Ritmo Aurora glassmorphism design system.
class RoutineTypePicker extends StatelessWidget {
  const RoutineTypePicker({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    this.itemType = 'ROUTINE',
    this.onItemTypeSelected,
  });

  final RoutineType selectedType;
  final ValueChanged<RoutineType> onTypeSelected;
  final String itemType;
  final ValueChanged<String>? onItemTypeSelected;

  static const List<RoutineTypeOption> options = [
    RoutineTypeOption(
      type: RoutineType.asNeeded,
      itemType: 'ROUTINE',
      titleFa: 'آزاد (شناور)',
      subtitleFa: 'ثبت آزاد در هر زمان بدون ساعت اجباری (PRN)',
      icon: Icons.bolt_rounded,
      badgeFa: 'پیش‌فرض',
    ),
    RoutineTypeOption(
      type: RoutineType.timeBased,
      itemType: 'ROUTINE',
      titleFa: 'زمان‌محور',
      subtitleFa: 'ساعت مشخص روزانه و اجرا با تایمر',
      icon: Icons.alarm_rounded,
      badgeFa: 'زمان‌بندی',
    ),
    RoutineTypeOption(
      type: RoutineType.countBased,
      itemType: 'ROUTINE',
      titleFa: 'شمارشی',
      subtitleFa: 'رسیدن به هدف عددی روزانه (بر حسب بار)',
      icon: Icons.tag_rounded,
      badgeFa: 'هدفمند',
    ),
    RoutineTypeOption(
      type: RoutineType.timeBased,
      itemType: 'REMINDER',
      titleFa: 'یادآور ساده',
      subtitleFa: 'هشدار و اعلان ساده در ساعت مشخص',
      icon: Icons.notifications_active_rounded,
      badgeFa: 'یادآور',
    ),
    RoutineTypeOption(
      type: RoutineType.progressive,
      itemType: 'ROUTINE',
      titleFa: 'پیش‌رونده',
      subtitleFa: 'شروع آرام و افزایش خودکار سختی (عادات اتمی)',
      icon: Icons.trending_up_rounded,
      badgeFa: 'تدریجی',
    ),
    RoutineTypeOption(
      type: RoutineType.intervalBased,
      itemType: 'ROUTINE',
      titleFa: 'فاصله‌ای',
      subtitleFa: 'تکرار منظم هر چند ساعت یک‌بار (دارو یا استراحت)',
      icon: Icons.timelapse_rounded,
      badgeFa: 'دوره‌ای',
    ),
    RoutineTypeOption(
      type: RoutineType.dependent,
      itemType: 'ROUTINE',
      titleFa: 'زنجیره‌ای',
      subtitleFa: 'اجرای خودکار بلافاصله پس از روتین دیگر',
      icon: Icons.link_rounded,
      badgeFa: 'وابسته',
    ),
  ];

  RoutineTypeOption get _selectedOption {
    return options.firstWhere(
      (opt) {
        if (itemType == 'REMINDER') {
          return opt.itemType == 'REMINDER';
        }
        return opt.itemType == 'ROUTINE' && opt.type == selectedType;
      },
      orElse: () => options.first,
    );
  }

  void _showDropdownSheet(BuildContext context) {
    RitmoHaptics.selection();
    final colors = context.colors;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.sheetBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
      ),
      builder: (sheetCtx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                RitmoSpacing.lg,
                RitmoSpacing.md,
                RitmoSpacing.lg,
                RitmoSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: RitmoSpacing.md),
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 20, color: colors.primary),
                      const SizedBox(width: RitmoSpacing.sm),
                      Text(
                        'انتخاب مدل اجرای روتین',
                        style: TextStyle(
                          fontSize: 16,
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
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: options.map((opt) {
                          final isSelected = opt.itemType == itemType &&
                              (opt.itemType == 'REMINDER' || opt.type == selectedType);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
                            child: InkWell(
                              onTap: () {
                                RitmoHaptics.selection();
                                onTypeSelected(opt.type);
                                onItemTypeSelected?.call(opt.itemType);
                                Navigator.of(sheetCtx).pop();
                              },
                              borderRadius: BorderRadius.circular(RitmoRadius.card),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primary.withValues(alpha: 0.12)
                                      : colors.card.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.primary
                                        : colors.border.withValues(alpha: 0.3),
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
                                                  fontSize: 13.5,
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                  color: isSelected
                                                      ? colors.primary
                                                      : colors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(width: RitmoSpacing.sm),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? colors.primary.withValues(alpha: 0.15)
                                                      : colors.border.withValues(alpha: 0.3),
                                                  borderRadius:
                                                      BorderRadius.circular(RitmoRadius.pill),
                                                ),
                                                child: Text(
                                                  opt.badgeFa,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isSelected
                                                        ? colors.primary
                                                        : colors.textTertiary,
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
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: colors.primary,
                                        size: 22,
                                      )
                                    else
                                      Icon(
                                        Icons.radio_button_unchecked_rounded,
                                        color: colors.border.withValues(alpha: 0.6),
                                        size: 22,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedOpt = _selectedOption;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: colors.primary),
              const SizedBox(width: RitmoSpacing.xs),
              Text(
                'مدل اجرای روتین',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'نحوهٔ یادآوری، ردیابی و تکمیل این روتین را انتخاب کنید:',
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _showDropdownSheet(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF16192E).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: 0.15),
                    ),
                    child: Icon(
                      selectedOpt.icon,
                      size: 18,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              selectedOpt.titleFa,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: RitmoSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(RitmoRadius.pill),
                              ),
                              child: Text(
                                selectedOpt.badgeFa,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          selectedOpt.subtitleFa,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
