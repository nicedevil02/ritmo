import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_planning_service.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// صفحهٔ ویرایشگر و تنظیم برنامهٔ هفتگی (P-16 / P-17 — زیر ۲۵۰ خط)
/// شامل ۳ سؤال ساده: تعداد روزها، روزهای هفته، ساعت یادآوری
class ActivityPlanEditorScreen extends StatefulWidget {
  const ActivityPlanEditorScreen({
    super.key,
    this.planningService,
    this.activityKindId,
  });

  final MovementPlanningService? planningService;
  final String? activityKindId;

  @override
  State<ActivityPlanEditorScreen> createState() => _ActivityPlanEditorScreenState();
}

class _ActivityPlanEditorScreenState extends State<ActivityPlanEditorScreen> {
  late final MovementPlanningService _planningService;

  int _daysPerWeek = 3;
  final Set<int> _selectedWeekdays = {0, 2, 4}; // شنبه، دوشنبه، چهارشنبه
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  bool _isSaving = false;

  static const List<String> _dayNames = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنج‌شنبه',
    'جمعه',
  ];

  @override
  void initState() {
    super.initState();
    _planningService = widget.planningService ?? MovementPlanningService();
  }

  void _toggleWeekday(int index) {
    setState(() {
      if (_selectedWeekdays.contains(index)) {
        if (_selectedWeekdays.length > 1) {
          _selectedWeekdays.remove(index);
          _daysPerWeek = _selectedWeekdays.length;
        }
      } else {
        if (_selectedWeekdays.length < 6) {
          _selectedWeekdays.add(index);
          _daysPerWeek = _selectedWeekdays.length;
        }
      }
    });
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final hourStr = _reminderTime.hour.toString().padLeft(2, '0');
      final minStr = _reminderTime.minute.toString().padLeft(2, '0');
      final timeStr = '$hourStr:$minStr';

      final weekdaysList = _selectedWeekdays.toList()..sort();

      await _planningService.createWeeklySimplePlan(
        weeklyGoalSessions: _daysPerWeek,
        preferredWeekdays: weekdaysList,
        reminderTime: timeStr,
        activityKindId: widget.activityKindId ?? 'kind_walking',
      );

      RitmoEventBus().fire(
        RitmoEvent(type: RitmoEventType.routineCreated.code),
      );

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final hourStr = toPersianDigits(_reminderTime.hour.toString().padLeft(2, '0'));
    final minStr = toPersianDigits(_reminderTime.minute.toString().padLeft(2, '0'));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          MovementStrings.plannerTitle,
          style: RitmoTextStyles.cardTitle(colors.textPrimary),
        ),
        backgroundColor: colors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(RitmoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // سؤال ۱: چند روز در هفته؟
              Text(
                '۱. چند روز در هفته می‌خوای تمرین کنی؟',
                style: RitmoTextStyles.titleMedium(colors.textPrimary),
              ),
              const SizedBox(height: RitmoSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int i = 2; i <= 6; i++)
                    ChoiceChip(
                      label: Text('${toPersianDigits(i)} روز'),
                      selected: _daysPerWeek == i,
                      selectedColor: sportsColor.withValues(alpha: 0.2),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _daysPerWeek = i;
                            // تنظیم خودکار روزها
                            _selectedWeekdays.clear();
                            for (int d = 0; d < i; d++) {
                              _selectedWeekdays.add((d * 2) % 7);
                            }
                          });
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: RitmoSpacing.xxl),

              // سؤال ۲: کدوم روزها؟
              Text(
                '۲. کدوم روزها برات مناسب‌تره؟',
                style: RitmoTextStyles.titleMedium(colors.textPrimary),
              ),
              const SizedBox(height: RitmoSpacing.sm),
              Wrap(
                spacing: RitmoSpacing.sm,
                runSpacing: RitmoSpacing.sm,
                children: [
                  for (int i = 0; i < 7; i++)
                    FilterChip(
                      label: Text(_dayNames[i]),
                      selected: _selectedWeekdays.contains(i),
                      selectedColor: sportsColor.withValues(alpha: 0.2),
                      checkmarkColor: sportsColor,
                      onSelected: (_) => _toggleWeekday(i),
                    ),
                ],
              ),
              const SizedBox(height: RitmoSpacing.xxl),

              // سؤال ۳: چه ساعتی یادآوری کنیم؟
              Text(
                '۳. چه ساعتی بهت یادآوری کنیم؟',
                style: RitmoTextStyles.titleMedium(colors.textPrimary),
              ),
              const SizedBox(height: RitmoSpacing.sm),
              InkWell(
                onTap: _pickReminderTime,
                borderRadius: BorderRadius.circular(RitmoRadius.card),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.lg,
                    vertical: RitmoSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: sportsColor),
                      const SizedBox(width: RitmoSpacing.md),
                      Text(
                        'ساعت $hourStr:$minStr',
                        style: RitmoTextStyles.body(colors.textPrimary),
                      ),
                      const Spacer(),
                      Icon(Icons.edit_outlined, size: 18, color: colors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: RitmoSpacing.xxxl),

              // دکمهٔ ذخیره برنامه
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: sportsColor,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                ),
                child: _isSaving
                    ? const Text('در حال ذخیره...')
                    : const Text('ذخیره و ایجاد برنامه'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
