// lib/features/routines/presentation/forms/simple_reminder_form.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/sheet/ritmo_picker_sheet.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';
import 'package:shamsi_date/shamsi_date.dart';

class SimpleReminderForm extends StatelessWidget {
  const SimpleReminderForm({super.key, required this.controller});
  final PlannerController controller;

  void _showDatePicker(BuildContext context, RitmoColors colors) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      controller.selectedDate = picked;
      controller.notifyListeners();
    }
  }

  void _showTimePicker(BuildContext context, RitmoColors colors) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: controller.selectedTime,
    );
    if (picked != null) {
      controller.selectedTime = picked;
      controller.notifyListeners();
    }
  }

  Future<void> _showReminderOffsetPicker(BuildContext context, RitmoColors colors) async {
    final options = [
      const PickerOption<int>(label: 'همزمان با موعد', value: 0),
      const PickerOption<int>(label: '۵ دقیقه قبل', value: 5),
      const PickerOption<int>(label: '۱۵ دقیقه قبل', value: 15),
      const PickerOption<int>(label: '۳۰ دقیقه قبل', value: 30),
      const PickerOption<int>(label: '۱ ساعت قبل', value: 60),
      const PickerOption<int>(label: '۲ ساعت قبل', value: 120),
    ];

    final selected = await RitmoPickerSheet.show<int>(
      context: context,
      title: 'تنظیم زمان هشدار پیش از موعد',
      options: options,
      initialValue: controller.reminderOffsetMinutes,
      enableSearch: false,
    );

    if (selected != null) {
      controller.reminderOffsetMinutes = selected;
      controller.notifyListeners();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final isToday = controller.selectedDate.year == now.year &&
        controller.selectedDate.month == now.month &&
        controller.selectedDate.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = controller.selectedDate.year == tomorrow.year &&
        controller.selectedDate.month == tomorrow.month &&
        controller.selectedDate.day == tomorrow.day;

    final jalali = Jalali.fromDateTime(controller.selectedDate);
    final dateLabel = isToday
        ? 'امروز'
        : (isTomorrow ? 'فردا' : '${jalali.day} ${jalali.formatter.mN}');

    final formatTime =
        '${toPersianDigits(controller.selectedTime.hour.toString().padLeft(2, '0'))}:${toPersianDigits(controller.selectedTime.minute.toString().padLeft(2, '0'))}';

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner Info Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_active_rounded, color: colors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'یادآور نقطه‌ای و اعلان سریع',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'بدون اشغال بازه زمانی روی تقویم، در ساعت مشخص هشدار می‌دهد.',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 0. Title Field Input (عنوان یادآور)
              TextFormField(
                initialValue: controller.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'عنوان یادآور *',
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                  hintText: 'مثلاً: پرداخت قسط وام، آلارم پرواز، تماس با دکتر...',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: colors.textSecondary.withValues(alpha: 0.4),
                  ),
                  prefixIcon: Icon(Icons.edit_note_rounded, size: 22, color: colors.primary),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF16192E).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.85),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: colors.primary, width: 1.8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (val) {
                  controller.title = val;
                  controller.inputController.text = val;
                },
              ),
              const SizedBox(height: 16),

              // Date & Time Picker Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    // Date row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: colors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'تاریخ یادآوری: $dateLabel',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Quick chips: Today, Tomorrow, Pick
                            GestureDetector(
                              onTap: () {
                                controller.selectedDate = now;
                                controller.notifyListeners();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isToday ? colors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isToday ? colors.primary : colors.border.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  'امروز',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isToday ? Colors.white : colors.textSecondary,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                controller.selectedDate = tomorrow;
                                controller.notifyListeners();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isTomorrow ? colors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isTomorrow ? colors.primary : colors.border.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  'فردا',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isTomorrow ? Colors.white : colors.textSecondary,
                                    fontWeight: isTomorrow ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                              color: (!isToday && !isTomorrow) ? colors.primary : colors.textSecondary,
                              onPressed: () => _showDatePicker(context, colors),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Time row
                    GestureDetector(
                      onTap: () => _showTimePicker(context, colors),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 18, color: colors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'ساعت دقیق هشدار',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  formatTime,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: colors.primary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Reminder offset & Importance switches
              GestureDetector(
                onTap: () => _showReminderOffsetPicker(context, colors),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.alarm_rounded, size: 18, color: colors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'پیش‌هشدار',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            controller.reminderOffsetMinutes == 0
                                ? 'همزمان با موعد'
                                : '${toPersianDigits(controller.reminderOffsetMinutes.toString())} دقیقه قبل',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: colors.textSecondary.withValues(alpha: 0.6)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Important / Starred Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('⭐️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'یادآور مهم و ستاره‌دار',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              'در بالای لیست کارهای روزانه رندر می‌شود.',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: controller.priority >= 1.5,
                      activeThumbColor: colors.primary,
                      onChanged: (val) {
                        controller.priority = val ? 1.5 : 1.0;
                        controller.notifyListeners();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Private / Confidential Switch
              GestureDetector(
                onTap: () {
                  RitmoHaptics.selection();
                  controller.isPrivate = !controller.isPrivate;
                  controller.notifyListeners();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: controller.isPrivate
                        ? colors.primary.withValues(alpha: isDark ? 0.14 : 0.08)
                        : (isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: controller.isPrivate
                          ? colors.primary.withValues(alpha: 0.5)
                          : colors.border.withValues(alpha: 0.1),
                      width: controller.isPrivate ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: controller.isPrivate
                              ? colors.primary.withValues(alpha: 0.18)
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          controller.isPrivate ? Icons.lock_rounded : Icons.lock_outline_rounded,
                          size: 18,
                          color: controller.isPrivate ? colors.primary : colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'اعلان خصوصی و محرمانه',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: controller.isPrivate ? colors.primary : colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'مخفی‌سازی متن در اعلان + قفل با اثرانگشت/رمز',
                              style: TextStyle(
                                fontSize: 11,
                                color: controller.isPrivate
                                    ? colors.primary.withValues(alpha: 0.85)
                                    : colors.textSecondary.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: controller.isPrivate,
                        activeThumbColor: colors.primary,
                        activeTrackColor: colors.primary.withValues(alpha: 0.35),
                        onChanged: (val) {
                          RitmoHaptics.selection();
                          controller.isPrivate = val;
                          controller.notifyListeners();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                initialValue: controller.description,
                maxLines: 2,
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'یادداشت یا جزئیات (اختیاری)',
                  labelStyle: TextStyle(fontSize: 12, color: colors.textSecondary),
                  prefixIcon: Icon(Icons.notes_rounded, size: 20, color: colors.primary.withValues(alpha: 0.7)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) => controller.description = val,
              ),
            ],
          ),
        );
      },
    );
  }
}
