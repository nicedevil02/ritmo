import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// گام ۲ از ۵ آنبوردینگ قدرت: سطح تجربه و محدودیت‌های ایمنی مفاصل
class StepLevelSafety extends StatelessWidget {
  const StepLevelSafety({
    super.key,
    required this.selectedLevel,
    required this.onLevelChanged,
    required this.sensitiveAreas,
    required this.onSensitiveAreasChanged,
  });

  final String selectedLevel;
  final ValueChanged<String> onLevelChanged;
  final List<String> sensitiveAreas;
  final ValueChanged<List<String>> onSensitiveAreasChanged;

  static const List<Map<String, String>> _levels = [
    {
      'id': 'beginner',
      'title': 'تازه‌کار (کمتر از ۶ ماه سابقه)',
      'desc': 'تمرکز بر یادگیری فرم صحیح حرکات و استراحت کافی',
    },
    {
      'id': 'intermediate',
      'title': 'متوسط (۶ ماه تا ۲ سال سابقه)',
      'desc': 'آشنایی کامل با الگوهای حرکتی و آمادگی برای حجم بیشتر',
    },
    {
      'id': 'advanced',
      'title': 'پیشرفته (بیش از ۲ سال سابقه)',
      'desc': 'شدت بالاتر، ست‌های سنگین‌تر و تکنیک‌های پیشرفته',
    },
  ];

  static const List<Map<String, String>> _areas = [
    {'id': 'knees', 'label': 'زانوها'},
    {'id': 'lower_back', 'label': 'پایین کمر'},
    {'id': 'shoulders', 'label': 'شانه‌ها'},
    {'id': 'wrists', 'label': 'مچ دست'},
    {'id': 'neck', 'label': 'گردن و بالای پشت'},
  ];

  void _toggleArea(String id) {
    final updated = List<String>.from(sensitiveAreas);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    onSensitiveAreasChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MovementStrings.strengthLevelTitle,
          style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        Text(
          'سطح تجربه برای تنظیم حجم و شدت تمرین استفاده می‌شود.',
          style: RitmoTextStyles.body(colors.textSecondary),
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // بخش ۱: سطح تجربه
        Text(
          'سطح تجربهٔ شما:',
          style: RitmoTextStyles.cardTitle(colors.textPrimary),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        ..._levels.map((lvl) {
          final isSelected = selectedLevel == lvl['id'];
          return Padding(
            padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
            child: InkWell(
              onTap: () => onLevelChanged(lvl['id']!),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              child: Container(
                padding: const EdgeInsets.all(RitmoSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected ? sportsColor.withValues(alpha: 0.1) : colors.surface,
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(
                    color: isSelected ? sportsColor : colors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? sportsColor : colors.textTertiary,
                          width: isSelected ? 6 : 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: RitmoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lvl['title']!,
                            style: RitmoTextStyles.label(
                              isSelected ? sportsColor : colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lvl['desc']!,
                            style: RitmoTextStyles.caption(colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: RitmoSpacing.lg),

        // بخش ۲: نواحی حساس یا آسیب‌دیده
        Text(
          'نواحی حساس یا آسیب‌دیده (اختیاری):',
          style: RitmoTextStyles.cardTitle(colors.textPrimary),
        ),
        const SizedBox(height: RitmoSpacing.xs),
        Text(
          'حرکاتی که به این نواحی فشار می‌آورند خودکار با حرکات ایمن جایگزین می‌شوند.',
          style: RitmoTextStyles.caption(colors.textSecondary),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        Wrap(
          spacing: RitmoSpacing.sm,
          runSpacing: RitmoSpacing.xs,
          children: _areas.map((a) {
            final isSel = sensitiveAreas.contains(a['id']);
            return FilterChip(
              label: Text(a['label']!),
              selected: isSel,
              selectedColor: colors.warning.withValues(alpha: 0.2),
              checkmarkColor: colors.warning,
              labelStyle: RitmoTextStyles.label(
                isSel ? colors.warning : colors.textSecondary,
              ),
              onSelected: (_) => _toggleArea(a['id']!),
            );
          }).toList(),
        ),

        const SizedBox(height: RitmoSpacing.xl),

        // بخش ۳: هشدار پزشکی الزام‌آور
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(RitmoSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: colors.textSecondary, size: 20),
              const SizedBox(width: RitmoSpacing.sm),
              Expanded(
                child: Text(
                  MovementStrings.strengthMedicalDisclaimer,
                  style: RitmoTextStyles.caption(colors.textSecondary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
