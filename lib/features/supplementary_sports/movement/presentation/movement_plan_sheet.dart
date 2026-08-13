// lib/features/supplementary_sports/movement/presentation/movement_plan_sheet.dart
//
// فاز ۲ — جریان ۳‌قدمی ساخت و ویرایش برنامهٔ ورزشی
// ۱. انتخاب نوع ورزش و تمرکز عضله
// ۲. انتخاب روزها و ساعت اختصاصی هر روز
// ۳. تنظیم یادآوری و هدف

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_tokens.dart';
import 'package:ritmo/features/routines/presentation/widgets/planner_day_of_week_selector.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_reminder_service.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_plan_writer.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_reminder_defaults.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_plan_item.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/movement_kind_selector.dart';

const String _fontFa = 'Vazirmatn';

Future<void> showMovementPlanSheet(
  BuildContext context, {
  Map<String, dynamic>? routineToEdit,
  VoidCallback? onSaved,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => MovementPlanSheet(
      routineToEdit: routineToEdit,
      onSaved: onSaved,
    ),
  );
}

class MovementPlanSheet extends StatefulWidget {
  const MovementPlanSheet({
    super.key,
    this.routineToEdit,
    this.onSaved,
  });

  final Map<String, dynamic>? routineToEdit;
  final VoidCallback? onSaved;

  @override
  State<MovementPlanSheet> createState() => _MovementPlanSheetState();
}

class _MovementPlanSheetState extends State<MovementPlanSheet> {
  bool get _isEditing => widget.routineToEdit != null;

  int _currentStep = 0; // 0 = نوع ورزش, 1 = روزها و زمان, 2 = یادآوری و هدف

  MovementKind? _selectedKind;
  String? _muscleFocus; // CHEST_UPPER, BACK_LATS, LEGS_GLUTES, CORE_ABS, FULL_BODY
  List<int> _selectedDays = <int>[]; // Dart weekdays (1..7)
  final Map<int, TimeOfDay> _dayTimes = {}; // Dart weekday -> TimeOfDay
  bool _hasReminder = true;
  int _reminderMinutes = MovementReminderDefaults.venueMinutes;
  bool _userChangedReminder = false;
  bool _isSaving = false;

  // Goals
  int _durationMinutes = 30;
  double _distanceKm = 3.0;
  int _laps = 10;
  double _elevationMeters = 100.0;
  int _steps = 4000;

  @override
  void initState() {
    super.initState();
    if (widget.routineToEdit == null) {
      final todayDart = DateTime.now().weekday;
      _selectedDays = <int>[todayDart];
      _dayTimes[todayDart] = const TimeOfDay(hour: 18, minute: 30);
    }
    _initFromRoutine();
  }

  TimeOfDay _defaultTimeForKind(MovementKind? kind) {
    if (kind == null) return const TimeOfDay(hour: 18, minute: 30);
    if (kind.isOutdoor) return const TimeOfDay(hour: 7, minute: 0);
    if (kind.isSocial) return const TimeOfDay(hour: 20, minute: 0);
    return const TimeOfDay(hour: 18, minute: 30);
  }

  Future<void> _initFromRoutine() async {
    final toEdit = widget.routineToEdit;
    if (toEdit == null) return;

    final kindCode = toEdit['movementKind']?.toString() ?? 'WALKING';
    final kinds = await MovementRepository.instance.getKinds(enabledOnly: false);
    final matchingKind = kinds.firstWhere(
      (k) => k.code == kindCode,
      orElse: () => kinds.isNotEmpty ? kinds.first : _fallbackKind(),
    );

    final routineId = toEdit['id']?.toString() ?? '';
    final days = <int>[];
    final dayTimes = <int, TimeOfDay>{};

    try {
      final db = await DatabaseHelper.instance.database;
      final schedules = await db.query(
        'routine_schedules',
        where: 'routineId = ?',
        whereArgs: [routineId],
      );

      if (schedules.isNotEmpty) {
        for (final s in schedules) {
          final timeStr = s['timeOfDay']?.toString() ?? '18:30';
          final parts = timeStr.split(':');
          final time = parts.length == 2
              ? TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]))
              : const TimeOfDay(hour: 18, minute: 30);

          final daysStr = s['daysOfWeek']?.toString() ?? '';
          for (final part in daysStr.split(',')) {
            final w = int.tryParse(part.trim());
            if (w != null) {
              if (!days.contains(w)) days.add(w);
              dayTimes[w] = time;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ss] MovementPlanSheet init error: $e');
    }

    if (days.isEmpty) {
      final daysStr = toEdit['daysOfWeek']?.toString() ?? '';
      if (daysStr.isNotEmpty) {
        days.addAll(daysStr.split(',').map((s) => int.parse(s.trim())));
      } else {
        days.add(DateTime.now().weekday);
      }
      final timeStr = toEdit['timeOfDay']?.toString() ?? '18:30';
      final parts = timeStr.split(':');
      final time = parts.length == 2
          ? TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]))
          : const TimeOfDay(hour: 18, minute: 30);
      for (final d in days) {
        dayTimes[d] = time;
      }
    }

    final targetVal = (toEdit['movementTargetValue'] as num? ?? 30.0).toDouble();
    final duration = (toEdit['targetDurationMinutes'] as num? ?? 30).toInt();
    final storedReminder = (toEdit['reminderOffsetMinutes'] as num? ?? 0).toInt();
    final storedMuscleFocus = toEdit['movementMuscleFocus']?.toString();

    setState(() {
      _selectedKind = matchingKind;
      _muscleFocus = storedMuscleFocus;
      _selectedDays = days;
      _dayTimes.clear();
      _dayTimes.addAll(dayTimes);
      _hasReminder = storedReminder != 0;
      _reminderMinutes = storedReminder != 0
          ? storedReminder
          : MovementReminderDefaults.minutesFor(matchingKind);
      _userChangedReminder = storedReminder != 0;
      _durationMinutes = duration;

      if (matchingKind.primaryMetric == MovementMetric.distance) {
        _distanceKm = targetVal;
      } else if (matchingKind.primaryMetric == MovementMetric.laps) {
        _laps = targetVal.toInt();
      } else if (matchingKind.primaryMetric == MovementMetric.elevation) {
        _elevationMeters = targetVal;
      } else if (matchingKind.primaryMetric == MovementMetric.steps) {
        _steps = targetVal.toInt();
      }
    });
  }

  void _onKindSelected(MovementKind kind) {
    setState(() {
      _selectedKind = kind;
      if (!_userChangedReminder) {
        _reminderMinutes = MovementReminderDefaults.minutesFor(kind);
        _hasReminder = _reminderMinutes > 0;
      }
      final defaultTime = _defaultTimeForKind(kind);
      for (final d in _selectedDays) {
        _dayTimes[d] = defaultTime;
      }
    });
  }

  MovementKind _fallbackKind() {
    return const MovementKind(
      code: 'WALKING',
      titleFa: 'پیاده‌روی',
      emoji: '🚶',
      family: MovementFamily.endurance,
      baseMet: 3.5,
      metLow: 2.5,
      metHigh: 4.5,
      primaryMetric: MovementMetric.duration,
      secondaryMetric: MovementMetric.none,
      isOutdoor: true,
      isSocial: false,
      needsVenue: false,
      jointImpact: 1,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 0,
    );
  }

  Future<void> _selectTimeForDay(int dartWeekday) async {
    final current = _dayTimes[dartWeekday] ?? _defaultTimeForKind(_selectedKind);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dayTimes[dartWeekday] = picked;
      });
    }
  }

  void _applyTimeToAllDays(TimeOfDay time) {
    setState(() {
      for (final day in _selectedDays) {
        _dayTimes[day] = time;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'ساعت ${toPersianDigits('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}')} روی همهٔ روزها اعمال شد ✓',
          style: const TextStyle(fontFamily: _fontFa),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  double _getTargetValue() {
    if (_selectedKind == null) return 30.0;
    return switch (_selectedKind!.primaryMetric) {
      MovementMetric.distance => _distanceKm,
      MovementMetric.laps => _laps.toDouble(),
      MovementMetric.elevation => _elevationMeters,
      MovementMetric.steps => _steps.toDouble(),
      _ => _durationMinutes.toDouble(),
    };
  }

  Future<void> _savePlan() async {
    if (_selectedKind == null || _isSaving) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حداقل یک روز در هفته را انتخاب کن',
            style: TextStyle(fontFamily: _fontFa),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final defaultTime = _defaultTimeForKind(_selectedKind);
      final dayTimesToSave = <int, TimeOfDay>{
        for (final d in _selectedDays) d: _dayTimes[d] ?? defaultTime,
      };

      await MovementPlanWriter.savePlan(
        routineId: widget.routineToEdit?['id'] as String?,
        kind: _selectedKind!,
        muscleFocus: _selectedKind!.family == MovementFamily.strength
            ? (_muscleFocus ?? 'FULL_BODY')
            : null,
        dayTimesDartWeekday: dayTimesToSave,
        targetDurationMinutes: _durationMinutes,
        targetValue: _getTargetValue(),
        reminderMinutes: _hasReminder ? _reminderMinutes : 0,
        isEditing: _isEditing,
        existingRoutineData: widget.routineToEdit,
      );

      RitmoHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'برنامه با موفقیت ویرایش شد ✓' : 'برنامهٔ هفته با موفقیت ثبت شد 🎉',
              style: const TextStyle(fontFamily: _fontFa),
            ),
          ),
        );
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ذخیره برنامه: $e', style: const TextStyle(fontFamily: _fontFa)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _archiveRoutine() async {
    if (!_isEditing) return;
    final routineId = widget.routineToEdit!['id'] as String;

    setState(() => _isSaving = true);
    try {
      await RitmoExecutionKernel.instance.execute(
        ArchiveRoutineCommand(routineId: routineId),
      );
      await MovementReminderService.rescheduleWeekReminders();
      RitmoHaptics.success();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('برنامه آرشیو شد 📥', style: TextStyle(fontFamily: _fontFa))),
        );
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در آرشیو برنامه: $e', style: const TextStyle(fontFamily: _fontFa))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'ویرایش برنامهٔ حرکت' : 'افزودن به هفته',
                        style: TextStyle(
                          fontFamily: _fontFa,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _stepSubtitle(_currentStep),
                        style: TextStyle(
                          fontFamily: _fontFa,
                          fontSize: 12,
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${toPersianDigits((_currentStep + 1).toString())} از ۳',
                      style: TextStyle(
                        fontFamily: _fontFa,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Progress line
            Row(
              children: [
                for (int i = 0; i < 3; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _currentStep ? colors.primary : colors.surfaceSunken,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: 20 + bottomInset,
                ),
                child: _buildCurrentStep(colors),
              ),
            ),
            _buildBottomBar(colors),
          ],
        ),
      ),
    );
  }

  String _stepSubtitle(int step) {
    return switch (step) {
      0 => 'قدم اول — انتخاب نوع ورزش و تمرکز',
      1 => 'قدم دوم — انتخاب روزها و ساعت هر روز',
      2 => 'قدم سوم — یادآوری و تنظیم هدف',
      _ => '',
    };
  }

  Widget _buildCurrentStep(RitmoColors colors) {
    return switch (_currentStep) {
      0 => _buildStep1KindAndFocus(colors),
      1 => _buildStep2DaysAndTimes(colors),
      2 => _buildStep3RemindersAndGoals(colors),
      _ => const SizedBox.shrink(),
    };
  }

  // ─── STEP 1: چه حرکتی؟ ──────────────────────────────────────────────────────
  Widget _buildStep1KindAndFocus(RitmoColors colors) {
    final isStrength = _selectedKind?.family == MovementFamily.strength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MovementKindSelector(
          selectedKind: _selectedKind,
          onKindSelected: _onKindSelected,
        ),
        if (isStrength) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'تمرکز عضلهٔ تمرین',
                      style: TextStyle(
                        fontFamily: _fontFa,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(اختیاری)',
                      style: TextStyle(
                        fontFamily: _fontFa,
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'برای فیلتر هوشمند کتابخانهٔ حرکات در جلسات',
                  style: TextStyle(
                    fontFamily: _fontFa,
                    fontSize: 11.5,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _muscleChip('تمام بدن ⚡', 'FULL_BODY', colors),
                    _muscleChip('سینه و بالاتنه 💪', 'CHEST_UPPER', colors),
                    _muscleChip('پشت و زیربغل 🛡️', 'BACK_LATS', colors),
                    _muscleChip('پا و باسن 🦵', 'LEGS_GLUTES', colors),
                    _muscleChip('شکم و پهلو 🍫', 'CORE_ABS', colors),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _muscleChip(String label, String code, RitmoColors colors) {
    final isSelected = (_muscleFocus ?? 'FULL_BODY') == code;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        RitmoHaptics.selection();
        setState(() => _muscleFocus = code);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryContainer : colors.surfaceSunken,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: _fontFa,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colors.primary : colors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ─── STEP 2: کدوم روزها؟ کی؟ ───────────────────────────────────────────────
  Widget _buildStep2DaysAndTimes(RitmoColors colors) {
    final defaultTime = _defaultTimeForKind(_selectedKind);
    // Sort selected Dart weekdays by Persian Sat0 order
    final sortedDays = List<int>.from(_selectedDays)
      ..sort((a, b) => dartWeekdayToSat0(a).compareTo(dartWeekdayToSat0(b)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'روزهای تکرار در هفته:',
          style: TextStyle(
            fontFamily: _fontFa,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        PlannerDayOfWeekSelector(
          selectedDays: _selectedDays,
          onChanged: (days) {
            setState(() {
              _selectedDays = days;
              for (final d in days) {
                _dayTimes.putIfAbsent(d, () => defaultTime);
              }
            });
          },
        ),
        const SizedBox(height: 20),
        if (sortedDays.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ساعت اختصاصی هر روز:',
                style: TextStyle(
                  fontFamily: _fontFa,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              if (sortedDays.length > 1)
                TextButton.icon(
                  onPressed: () {
                    final firstTime = _dayTimes[sortedDays.first] ?? defaultTime;
                    _applyTimeToAllDays(firstTime);
                  },
                  icon: Icon(Icons.sync_rounded, size: 16, color: colors.primary),
                  label: Text(
                    'یکسان‌سازی ساعت',
                    style: TextStyle(
                      fontFamily: _fontFa,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final dartDay in sortedDays) _buildDayTimeTile(dartDay, colors),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                'برای تنظیم ساعت، حداقل یک روز را انتخاب کنید.',
                style: TextStyle(fontFamily: _fontFa, color: colors.textSecondary, fontSize: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayTimeTile(int dartWeekday, RitmoColors colors) {
    final sat0 = dartWeekdayToSat0(dartWeekday);
    final dayName = kPersianWeekdayNames[sat0];
    final time = _dayTimes[dartWeekday] ?? _defaultTimeForKind(_selectedKind);
    final timeFormatted =
        toPersianDigits('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.calendar_today_rounded, size: 16, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              dayName,
              style: TextStyle(
                fontFamily: _fontFa,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _selectTimeForDay(dartWeekday),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 15, color: colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    timeFormatted,
                    style: TextStyle(
                      fontFamily: _fontFa,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 3: یادآوری و هدف ────────────────────────────────────────────────
  Widget _buildStep3RemindersAndGoals(RitmoColors colors) {
    final kind = _selectedKind ?? _fallbackKind();
    final hasMorningSession = _dayTimes.values.any((t) => t.hour < 12);
    final showNightBefore = kind.isOutdoor && hasMorningSession;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reminder section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, color: colors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'ارسال یادآوری قبل از حرکت',
                        style: TextStyle(
                          fontFamily: _fontFa,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _hasReminder,
                    activeTrackColor: colors.primary,
                    onChanged: (val) {
                      setState(() {
                        _hasReminder = val;
                        _userChangedReminder = true;
                      });
                    },
                  ),
                ],
              ),
              if (_hasReminder) ...[
                const SizedBox(height: 12),
                Text(
                  'زمان یادآوری:',
                  style: TextStyle(
                    fontFamily: _fontFa,
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _reminderChip('۱۰ دقیقه قبل', 10, colors),
                    _reminderChip('۳۰ دقیقه قبل', 30, colors),
                    _reminderChip('۱ ساعت قبل', 60, colors),
                    _reminderChip('۱.۵ ساعت قبل', 90, colors),
                    if (showNightBefore)
                      _reminderChip('شب قبل (۲۱:۰۰) 🌙', -1, colors),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Goals section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'هدف هر جلسه (${kind.emoji} ${kind.titleFa}):',
                style: TextStyle(
                  fontFamily: _fontFa,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('مدت زمان هدف:', style: TextStyle(fontFamily: _fontFa, color: colors.textPrimary)),
                  Text(
                    '${toPersianDigits(_durationMinutes.toString())} دقیقه',
                    style: TextStyle(
                      fontFamily: _fontFa,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _durationMinutes.toDouble(),
                min: 5,
                max: 180,
                divisions: 35,
                activeColor: colors.primary,
                onChanged: (val) => setState(() => _durationMinutes = val.toInt()),
              ),
              if (kind.primaryMetric == MovementMetric.distance) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('مسافت هدف:', style: TextStyle(fontFamily: _fontFa, color: colors.textPrimary)),
                    Text(
                      '${toPersianDigits(_distanceKm.toStringAsFixed(1))} کیلومتر',
                      style: TextStyle(fontFamily: _fontFa, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                  ],
                ),
                Slider(
                  value: _distanceKm,
                  min: 0.5,
                  max: 50.0,
                  divisions: 99,
                  activeColor: colors.primary,
                  onChanged: (val) => setState(() => _distanceKm = val),
                ),
              ] else if (kind.primaryMetric == MovementMetric.laps) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تعداد طول (استخر ۲۵ متری):', style: TextStyle(fontFamily: _fontFa, color: colors.textPrimary)),
                    Text(
                      '${toPersianDigits(_laps.toString())} طول (${toPersianDigits((_laps * 25).toString())} متر)',
                      style: TextStyle(fontFamily: _fontFa, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                  ],
                ),
                Slider(
                  value: _laps.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  activeColor: colors.primary,
                  onChanged: (val) => setState(() => _laps = val.toInt()),
                ),
              ] else if (kind.primaryMetric == MovementMetric.elevation) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ارتفاع صعود:', style: TextStyle(fontFamily: _fontFa, color: colors.textPrimary)),
                    Text(
                      '${toPersianDigits(_elevationMeters.round().toString())} متر',
                      style: TextStyle(fontFamily: _fontFa, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                  ],
                ),
                Slider(
                  value: _elevationMeters,
                  min: 10,
                  max: 2000,
                  divisions: 199,
                  activeColor: colors.primary,
                  onChanged: (val) => setState(() => _elevationMeters = val),
                ),
              ] else if (kind.primaryMetric == MovementMetric.steps) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تعداد گام:', style: TextStyle(fontFamily: _fontFa, color: colors.textPrimary)),
                    Text(
                      '${toPersianDigits(_steps.toString())} گام',
                      style: TextStyle(fontFamily: _fontFa, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                  ],
                ),
                Slider(
                  value: _steps.toDouble(),
                  min: 500,
                  max: 30000,
                  divisions: 59,
                  activeColor: colors.primary,
                  onChanged: (val) => setState(() => _steps = val.toInt()),
                ),
              ],
            ],
          ),
        ),
        if (_isEditing) ...[
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: colors.error),
              icon: const Icon(CupertinoIcons.trash, size: 18),
              label: const Text(
                'آرشیو و حذف این برنامه',
                style: TextStyle(fontFamily: _fontFa, fontWeight: FontWeight.bold),
              ),
              onPressed: _archiveRoutine,
            ),
          ),
        ],
      ],
    );
  }

  Widget _reminderChip(String label, int minutes, RitmoColors colors) {
    final isSelected = _reminderMinutes == minutes;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontFamily: _fontFa, fontSize: 12)),
      selected: isSelected,
      selectedColor: colors.primary,
      backgroundColor: colors.surfaceSunken,
      labelStyle: TextStyle(
        fontFamily: _fontFa,
        color: isSelected ? colors.onPrimary : colors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) {
          RitmoHaptics.selection();
          setState(() {
            _reminderMinutes = minutes;
            _userChangedReminder = true;
          });
        }
      },
    );
  }

  // ─── BOTTOM ACTION BAR ─────────────────────────────────────────────────────
  Widget _buildBottomBar(RitmoColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: colors.border),
              ),
              onPressed: () {
                RitmoHaptics.tap();
                setState(() => _currentStep--);
              },
              child: Text(
                'قبلی',
                style: TextStyle(
                  fontFamily: _fontFa,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CalendarTokens.emerald,
                foregroundColor: const Color(0xFF042116),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSaving
                  ? null
                  : () {
                      RitmoHaptics.tap();
                      if (_currentStep < 2) {
                        if (_currentStep == 0 && _selectedKind == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'لطفاً نوع ورزش را انتخاب کن',
                                style: TextStyle(fontFamily: _fontFa),
                              ),
                            ),
                          );
                          return;
                        }
                        if (_currentStep == 1 && _selectedDays.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'حداقل یک روز در هفته را انتخاب کن',
                                style: TextStyle(fontFamily: _fontFa),
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _currentStep++);
                      } else {
                        _savePlan();
                      }
                    },
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF042116)),
                    )
                  : Text(
                      _currentStep < 2
                          ? 'ادامه'
                          : (_isEditing ? 'ذخیره تغییرات' : 'ثبت برنامه در هفته'),
                      style: const TextStyle(
                        fontFamily: _fontFa,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
