// lib/features/routines/presentation/forms/generic_step2_form.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';
import 'package:ritmo/features/routines/presentation/widgets/planner_advanced_section.dart';
import 'package:ritmo/features/routines/presentation/widgets/planner_timeline_picker.dart';
import 'package:ritmo/features/routines/presentation/widgets/planner_weekdays_picker.dart';

class GenericStep2Form extends StatelessWidget {
  const GenericStep2Form({super.key, required this.controller});
  final PlannerController controller;

  void _showDurationManualDialog(BuildContext context, RitmoColors colors) {
    final textController = TextEditingController(text: controller.targetDuration.toString());
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: colors.sheetBackground,
            title: const Text(
              'وارد کردن دستی مدت زمان',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'مدت زمان مورد نظر خود را به دقیقه وارد کنید:',
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    suffixText: 'دقیقه',
                    suffixStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('لغو', style: TextStyle(fontFamily: 'Vazirmatn', color: colors.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  final val = int.tryParse(textController.text);
                  if (val != null && val > 0) {
                    controller.targetDuration = val;
                    controller.notifyListeners();
                  }
                  Navigator.pop(context);
                },
                child: const Text('تایید', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReminderPicker(BuildContext context, RitmoColors colors) {
    final options = [
      {'label': 'همزمان با شروع', 'value': 0},
      {'label': '۵ دقیقه قبل', 'value': 5},
      {'label': '۱۰ دقیقه قبل', 'value': 10},
      {'label': '۱۵ دقیقه قبل', 'value': 15},
      {'label': '۳۰ دقیقه قبل', 'value': 30},
      {'label': '۱ ساعت قبل', 'value': 60},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تنظیم زمان یادآوری',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final isSelected = controller.reminderOffsetMinutes == opt['value'];
                  return ListTile(
                    title: Text(
                      opt['label']! as String,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? colors.primary : colors.textPrimary,
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check_rounded, color: colors.primary) : null,
                    onTap: () {
                      controller.reminderOffsetMinutes = opt['value']! as int;
                      controller.notifyListeners();
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRecurrencePicker(BuildContext context, RitmoColors colors) {
    final options = [
      {'label': 'روزانه (هر روز)', 'value': 'EVERY_DAY'},
      {'label': 'روزهای انتخابی (هفتگی)', 'value': 'CUSTOM_DAYS'},
      {'label': 'فقط یک‌بار (بدون تکرار)', 'value': 'ONCE'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تنظیم نوع تکرار',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final isSelected = controller.recurrenceType == opt['value'];
                  return ListTile(
                    title: Text(
                      opt['label']!,
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? colors.primary : colors.textPrimary,
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check_rounded, color: colors.primary) : null,
                    onTap: () {
                      controller.recurrenceType = opt['value']!;
                      controller.notifyListeners();
                      Navigator.pop(context);
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
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

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              PlannerTimelinePicker(controller: controller),
              const SizedBox(height: 28),
              
              // 1. Duration Picker Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'مدت زمان',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2235).withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: () => controller.adjustDuration(-15),
                            color: colors.textPrimary.withValues(alpha: 0.6),
                          ),
                          GestureDetector(
                            onTap: () => _showDurationManualDialog(context, colors),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text(
                                '${toPersianDigits(controller.targetDuration.toString())} دقیقه',
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () => controller.adjustDuration(15),
                            color: colors.textPrimary.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Recurrence Card
              GestureDetector(
                onTap: () => _showRecurrencePicker(context, colors),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'تکرار',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            controller.recurrenceType == 'EVERY_DAY'
                                ? 'روزانه (هر روز)'
                                : (controller.recurrenceType == 'CUSTOM_DAYS' || controller.recurrenceType == 'WEEKLY'
                                    ? 'روزهای انتخابی'
                                    : 'فقط یک‌بار'),
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 14,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.sync_rounded, size: 18, color: colors.textSecondary.withValues(alpha: 0.7)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Weekdays selector if custom days or weekly
              if (controller.recurrenceType == 'CUSTOM_DAYS' || controller.recurrenceType == 'WEEKLY') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'روزهای تکرار در هفته:',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      PlannerWeekdaysPicker(
                        selectedDays: controller.worshipSelectedDays,
                        onChanged: (days) {
                          controller.worshipSelectedDays = days;
                          controller.notifyListeners();
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // 3. Reminder Card
              GestureDetector(
                onTap: () => _showReminderPicker(context, colors),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'یادآوری',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            controller.reminderOffsetMinutes == 0
                                ? 'همزمان با شروع'
                                : '${toPersianDigits(controller.reminderOffsetMinutes.toString())} دقیقه قبل',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 14,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.textSecondary.withValues(alpha: 0.6)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Advanced Settings Card
              PlannerAdvancedSection(controller: controller),
            ],
          ),
        );
      },
    );
  }
}
