import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// گام ۳ از ۵ آنبوردینگ قدرت: تجهیزات ورزشی در دسترس در خانه
class StepEquipment extends StatelessWidget {
  const StepEquipment({
    super.key,
    required this.selectedEquipment,
    required this.onEquipmentChanged,
  });

  final List<String> selectedEquipment;
  final ValueChanged<List<String>> onEquipmentChanged;

  static const List<Map<String, String>> _equipmentList = [
    {
      'id': 'bodyweight',
      'title': 'فقط وزن بدن (بدون تجهیزات)',
      'desc': 'حرکات تمرینی بر پایهٔ وزن بدن مانند شنا، اسکات و پلانک',
      'icon': 'accessibility',
    },
    {
      'id': 'resistance_bands',
      'title': 'کش ورزشی مقاومتی (لوپ / مینی‌لوپ)',
      'desc': 'فوق‌العاده برای ایجاد مقاومت تدریجی و سلامت مفاصل',
      'icon': 'fitness_center',
    },
    {
      'id': 'dumbbells',
      'title': 'دمبل (قابل تنظیم یا وزن ثابت)',
      'desc': 'بهترین گزینه برای افزایش تدریجی بار و پیشرفت عضلانی',
      'icon': 'fitness_center',
    },
    {
      'id': 'kettlebell',
      'title': 'کتل‌بل',
      'desc': 'مناسب برای حرکات پرتوان و استقامت عضلانی',
      'icon': 'sports_gymnastics',
    },
    {
      'id': 'pullup_bar',
      'title': 'میله بارفیکس یا کشش',
      'desc': 'تمرینات کلیدی عضلات پشت و زیربغل',
      'icon': 'horizontal_rule',
    },
    {
      'id': 'bench',
      'title': 'نیمکت یا صندلی محکم',
      'desc': 'مناسب برای پرس‌ها، دیپ و حرکات تعادلی',
      'icon': 'event_seat',
    },
  ];

  void _toggle(String id) {
    final updated = List<String>.from(selectedEquipment);
    if (updated.contains(id)) {
      if (updated.length > 1) {
        updated.remove(id);
      }
    } else {
      updated.add(id);
    }
    onEquipmentChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MovementStrings.strengthEquipmentTitle,
          style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        Text(
          'تجهیزاتی که در خانه دارید را انتخاب کنید (امکان انتخاب چندگانه وجود دارد).',
          style: RitmoTextStyles.body(colors.textSecondary),
        ),
        const SizedBox(height: RitmoSpacing.lg),
        ..._equipmentList.map((eq) {
          final isSelected = selectedEquipment.contains(eq['id']);
          return Padding(
            padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
            child: InkWell(
              onTap: () => _toggle(eq['id']!),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              child: Container(
                padding: const EdgeInsets.all(RitmoSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected
                      ? sportsColor.withValues(alpha: 0.1)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(
                    color: isSelected ? sportsColor : colors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggle(eq['id']!),
                      activeColor: sportsColor,
                    ),
                    const SizedBox(width: RitmoSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eq['title']!,
                            style: RitmoTextStyles.label(
                              isSelected ? sportsColor : colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            eq['desc']!,
                            style: RitmoTextStyles.caption(
                              colors.textSecondary,
                            ),
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
      ],
    );
  }
}
