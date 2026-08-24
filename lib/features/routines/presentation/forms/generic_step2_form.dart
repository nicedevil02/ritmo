// lib/features/routines/presentation/forms/generic_step2_form.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/routines/presentation/planner_controller.dart';
import 'package:ritmo/features/routines/presentation/widgets/planner_advanced_section.dart';
import 'package:ritmo/features/routines/presentation/widgets/planner_timeline_picker.dart';
import 'package:ritmo/features/routines/presentation/widgets/planner_weekdays_picker.dart';
import 'package:ritmo/features/routines/presentation/widgets/routine_type_picker.dart';

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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'مدت زمان مورد نظر خود را به دقیقه وارد کنید:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    suffixText: 'دقیقه',
                    suffixStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('لغو', style: TextStyle(color: colors.textSecondary)),
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
                child: const Text('تایید', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final isSelected = controller.reminderOffsetMinutes == opt['value'];
                  return ListTile(
                    title: Text(
                      opt['label']! as String,
                      style: TextStyle(
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final isSelected = controller.recurrenceType == opt['value'];
                  return ListTile(
                    title: Text(
                      opt['label']!,
                      style: TextStyle(
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 0. Title Field Input (عنوان رویداد/عادت)
              TextFormField(
                initialValue: controller.title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'عنوان فعالیت *',
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                  hintText: 'مثلاً: نوشیدن آب، تمرین یوگا، مطالعه کتاب...',
                  hintStyle: TextStyle(
                    fontSize: 11.5,
                    color: colors.textSecondary.withValues(alpha: 0.4),
                  ),
                  prefixIcon: Icon(Icons.edit_note_rounded, size: 19, color: colors.primary),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF16192E).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.85),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.primary, width: 1.6),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (val) {
                  controller.title = val;
                  controller.inputController.text = val;
                },
              ),
              const SizedBox(height: 14),

              // 1. Routine Type Selector (مدل اجرای روتین)
              RoutineTypePicker(
                selectedType: controller.routineType,
                itemType: controller.itemType,
                onTypeSelected: (type) {
                  controller.setRoutineType(type);
                },
                onItemTypeSelected: (type) {
                  controller.itemType = type;
                  controller.notifyListeners();
                },
              ),
              const SizedBox(height: 18),

              // 2. Dynamic Type-Specific Configuration Sections
              ..._buildTypeSpecificSections(context, colors, isDark),

              const SizedBox(height: 16),

              // 3. Advanced Settings Accordion
              PlannerAdvancedSection(controller: controller),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildTypeSpecificSections(BuildContext context, RitmoColors colors, bool isDark) {
    if (controller.itemType == 'REMINDER') {
      return [
        PlannerTimelinePicker(controller: controller),
        const SizedBox(height: 12),
        _buildRecurrenceCard(context, colors, isDark),
        const SizedBox(height: 12),
        _buildReminderCard(context, colors, isDark),
        const SizedBox(height: 12),
        _buildPrivateReminderCard(context, colors, isDark),
      ];
    }

    if (controller.itemType == 'EVENT') {
      return [
        PlannerTimelinePicker(controller: controller),
        const SizedBox(height: 20),
        _buildDurationCard(context, colors, isDark),
        const SizedBox(height: 12),
        _buildRecurrenceCard(context, colors, isDark),
        const SizedBox(height: 12),
        _buildReminderCard(context, colors, isDark),
        const SizedBox(height: 12),
        _buildPrivateReminderCard(context, colors, isDark),
      ];
    }

    switch (controller.routineType) {
      case RoutineType.timeBased:
        return [
          PlannerTimelinePicker(controller: controller),
          const SizedBox(height: 20),
          _buildDurationCard(context, colors, isDark),
          const SizedBox(height: 12),
          _buildRecurrenceCard(context, colors, isDark),
          const SizedBox(height: 12),
          _buildReminderCard(context, colors, isDark),
          const SizedBox(height: 12),
          _buildPrivateReminderCard(context, colors, isDark),
        ];

      case RoutineType.countBased:
        return [
          _buildCountBasedSection(context, colors, isDark),
          const SizedBox(height: 12),
          _buildRecurrenceCard(context, colors, isDark),
          const SizedBox(height: 12),
          _buildReminderCard(context, colors, isDark),
          const SizedBox(height: 12),
          _buildPrivateReminderCard(context, colors, isDark),
        ];

      case RoutineType.progressive:
        return [
          _buildProgressiveSection(context, colors, isDark),
          const SizedBox(height: 12),
          PlannerTimelinePicker(controller: controller),
          const SizedBox(height: 12),
          _buildRecurrenceCard(context, colors, isDark),
          const SizedBox(height: 12),
          _buildReminderCard(context, colors, isDark),
          const SizedBox(height: 12),
          _buildPrivateReminderCard(context, colors, isDark),
        ];

      case RoutineType.intervalBased:
        return [
          _buildIntervalBasedSection(context, colors, isDark),
          const SizedBox(height: 12),
          _buildReminderCard(context, colors, isDark),
          const SizedBox(height: 12),
          _buildPrivateReminderCard(context, colors, isDark),
        ];

      case RoutineType.dependent:
        return [
          _buildDependentSection(context, colors, isDark),
          const SizedBox(height: 12),
          _buildDurationCard(context, colors, isDark),
          const SizedBox(height: 12),
          _buildPrivateReminderCard(context, colors, isDark),
        ];

      case RoutineType.asNeeded:
        return [
          _buildAsNeededSection(context, colors, isDark),
          const SizedBox(height: 12),
          _buildDurationCard(context, colors, isDark),
        ];
    }
  }

  Widget _buildDurationCard(BuildContext context, RitmoColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'مدت زمان',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2235).withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: () => controller.adjustDuration(-15),
                  color: colors.textPrimary.withValues(alpha: 0.6),
                ),
                GestureDetector(
                  onTap: () => _showDurationManualDialog(context, colors),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '${toPersianDigits(controller.targetDuration.toString())} دقیقه',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => controller.adjustDuration(15),
                  color: colors.textPrimary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurrenceCard(BuildContext context, RitmoColors colors, bool isDark) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _showRecurrencePicker(context, colors),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تکرار',
                  style: TextStyle(
                    fontSize: 13.5,
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
                      style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.sync_rounded, size: 16, color: colors.textSecondary.withValues(alpha: 0.7)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (controller.recurrenceType == 'CUSTOM_DAYS' || controller.recurrenceType == 'WEEKLY') ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'روزهای تکرار در هفته:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
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
      ],
    );
  }

  Widget _buildReminderCard(BuildContext context, RitmoColors colors, bool isDark) {
    return GestureDetector(
      onTap: () => _showReminderPicker(context, colors),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'یادآوری',
              style: TextStyle(
                fontSize: 13.5,
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
                  style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_ios_rounded, size: 13, color: colors.textSecondary.withValues(alpha: 0.6)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateReminderCard(BuildContext context, RitmoColors colors, bool isDark) {
    final isSelected = controller.isPrivate;
    return GestureDetector(
      onTap: () {
        RitmoHaptics.selection();
        controller.isPrivate = !controller.isPrivate;
        controller.notifyListeners();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: isDark ? 0.14 : 0.08)
              : (isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.5)
                : colors.border.withValues(alpha: 0.1),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.18)
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected ? Icons.lock_rounded : Icons.lock_outline_rounded,
                size: 18,
                color: isSelected ? colors.primary : colors.textSecondary,
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? colors.primary : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'مخفی‌سازی متن در اعلان + قفل با اثرانگشت/رمز',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isSelected
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
              value: isSelected,
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
    );
  }

  Widget _buildCountBasedSection(BuildContext context, RitmoColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هدف عددی روزانه',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'تعداد دفعات تکرار در هر روز',
                style: TextStyle(
                  fontSize: 11.5,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 22),
                onPressed: () {
                  if (controller.countTarget > 1) {
                    RitmoHaptics.selection();
                    controller.countTarget--;
                    controller.notifyListeners();
                  }
                },
                color: colors.primary,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${toPersianDigits(controller.countTarget.toString())} بار',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 22),
                onPressed: () {
                  RitmoHaptics.selection();
                  controller.countTarget++;
                  controller.notifyListeners();
                },
                color: colors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressiveSection(BuildContext context, RitmoColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'تنظیمات پیشرفت تدریجی (عادت اتمی)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildNumberInputField(
                  label: 'مدت شروع (دقیقه)',
                  value: controller.progressionStart,
                  onChanged: (v) {
                    controller.progressionStart = v;
                    controller.notifyListeners();
                  },
                  colors: colors,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildNumberInputField(
                  label: 'پله افزایش (دقیقه)',
                  value: controller.progressionStep,
                  onChanged: (v) {
                    controller.progressionStep = v;
                    controller.notifyListeners();
                  },
                  colors: colors,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildNumberInputField(
                  label: 'هدف نهایی (دقیقه)',
                  value: controller.progressionTarget,
                  onChanged: (v) {
                    controller.progressionTarget = v;
                    controller.notifyListeners();
                  },
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مسیر: از ${toPersianDigits(controller.progressionStart.toString())} دقیقه شروع می‌شود و با هر ۷ بار اجرای موفق، ${toPersianDigits(controller.progressionStep.toString())} دقیقه به آن اضافه خواهد شد تا به ${toPersianDigits(controller.progressionTarget.toString())} دقیقه برسد.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntervalBasedSection(BuildContext context, RitmoColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timelapse_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'تنظیم فاصله تکرار',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildNumberInputField(
                  label: 'فاصله زمانی (ساعت)',
                  value: controller.minIntervalHours,
                  onChanged: (v) {
                    controller.minIntervalHours = v;
                    controller.notifyListeners();
                  },
                  colors: colors,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberInputField(
                  label: 'حداکثر دفعات در روز',
                  value: controller.maxDosesPerDay,
                  onChanged: (v) {
                    controller.maxDosesPerDay = v;
                    controller.notifyListeners();
                  },
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'یادآور بعدی پس از هر بار ثبت، به طور خودکار ${toPersianDigits(controller.minIntervalHours.toString())} ساعت بعد فعال می‌شود.',
            style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDependentSection(BuildContext context, RitmoColors colors, bool isDark) {
    final available = controller.todayOtherRoutines;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'انتخاب روتین والد (زنجیره عادت)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (available.isEmpty)
            Text(
              'ابتدا یک روتین اصلی ثبت کنید تا بتوانید این روتین را به آن پیوند دهید.',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: controller.dependsOnRoutineId,
              hint: const Text('انتخاب روتین پیش‌نیاز...'),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: available.map((r) {
                return DropdownMenuItem<String>(
                  value: r['id'] as String,
                  child: Text(r['title'] as String? ?? 'بدون عنوان'),
                );
              }).toList(),
              onChanged: (val) {
                controller.dependsOnRoutineId = val;
                controller.notifyListeners();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAsNeededSection(BuildContext context, RitmoColors colors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16192E).withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'این روتین ساعت مشخصی در طول روز ندارد و هر زمان مایل بودید می‌توانید آن را ثبت کنید.',
              style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInputField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    required RitmoColors colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value.toString(),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            if (parsed != null && parsed > 0) {
              onChanged(parsed);
            }
          },
        ),
      ],
    );
  }
}
