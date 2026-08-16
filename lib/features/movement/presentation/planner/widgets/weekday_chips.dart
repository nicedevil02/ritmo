import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_planning_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_plan_schedule.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// انتخابگر روزهای هفته از شنبه تا جمعه (RTL) با هدف لمسی حداقل ۴۸x۴۸ و زمان مشترک یا مجزا
class WeekdayChips extends StatefulWidget {
  const WeekdayChips({
    super.key,
    required this.initialSchedules,
    required this.onSchedulesChanged,
  });

  final List<MovementPlanSchedule> initialSchedules;
  final ValueChanged<List<MovementPlanSchedule>> onSchedulesChanged;

  @override
  State<WeekdayChips> createState() => _WeekdayChipsState();
}

class _WeekdayChipsState extends State<WeekdayChips> {
  static const _weekdayNames = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
  static const _weekdayFullNames = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  late final Map<int, String> _selectedDaysWithTime;
  bool _isSharedTime = true;
  String _sharedTime = '18:30';
  String _recurrence = 'weekly';
  int _weeksCount = 4;

  @override
  void initState() {
    super.initState();
    _selectedDaysWithTime = {};
    for (final s in widget.initialSchedules) {
      _selectedDaysWithTime[s.weekday] = s.timeOfDay;
      _recurrence = s.recurrence;
      if (s.weeksCount != null) _weeksCount = s.weeksCount!;
      _sharedTime = s.timeOfDay;
    }

    if (_selectedDaysWithTime.isEmpty) {
      final todayWeekday = MovementPlanningService.getRitmoWeekday(DateTime.now());
      _selectedDaysWithTime[todayWeekday] = _sharedTime;
    }
  }

  void _notifyChanges() {
    final list = _selectedDaysWithTime.entries.map((e) {
      return MovementPlanSchedule(
        id: '',
        templateId: '',
        weekday: e.key,
        timeOfDay: _isSharedTime ? _sharedTime : e.value,
        recurrence: _recurrence,
        weeksCount: _recurrence == 'nWeeks' ? _weeksCount : null,
        startDateIso: MovementPlanningService.formatIso(DateTime.now()),
        createdAt: DateTime.now(),
      );
    }).toList();

    widget.onSchedulesChanged(list);
  }

  void _toggleDay(int weekday) {
    setState(() {
      if (_selectedDaysWithTime.containsKey(weekday)) {
        if (_selectedDaysWithTime.length > 1) {
          _selectedDaysWithTime.remove(weekday);
        }
      } else {
        _selectedDaysWithTime[weekday] = _sharedTime;
      }
    });
    _notifyChanges();
  }

  Future<void> _pickTimeForDay(int? weekday) async {
    final currentTimeStr = weekday != null
        ? (_selectedDaysWithTime[weekday] ?? _sharedTime)
        : _sharedTime;

    final parts = currentTimeStr.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 18,
      minute: int.tryParse(parts.last) ?? 30,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (weekday == null || _isSharedTime) {
          _sharedTime = formatted;
          for (final k in _selectedDaysWithTime.keys.toList()) {
            _selectedDaysWithTime[k] = formatted;
          }
        } else {
          _selectedDaysWithTime[weekday] = formatted;
        }
      });
      _notifyChanges();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // سربرگ
          Text(
            MovementStrings.plannerStepSchedule,
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.md),

          // انتخاب روزهای هفته (شنبه تا جمعه)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isSelected = _selectedDaysWithTime.containsKey(index);
              return Semantics(
                label:
                    '${_weekdayFullNames[index]}${isSelected ? '، انتخاب‌شده، ساعت ${_selectedDaysWithTime[index]}' : ''}',
                button: true,
                child: InkWell(
                  onTap: () => _toggleDay(index),
                  borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
                  child: Container(
                    width: 44,
                    height: 48, // Touch target >= 48
                    decoration: BoxDecoration(
                      color: isSelected ? sportsColor : colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
                      border: Border.all(
                        color: isSelected ? sportsColor : colors.border,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _weekdayNames[index],
                      style: RitmoTextStyles.label(
                        isSelected ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // تاگل زمان مشترک در مقابل زمان به ازای هر روز
          Row(
            children: [
              Text(
                'زمان جلسه:',
                style: RitmoTextStyles.body(colors.textPrimary),
              ),
              const Spacer(),
              Text(
                _isSharedTime ? 'ساعت یکسان برای همه روزها' : 'ساعت مجزا برای هر روز',
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
              Switch(
                value: _isSharedTime,
                activeThumbColor: sportsColor,
                onChanged: (val) {
                  setState(() => _isSharedTime = val);
                  _notifyChanges();
                },
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // انتخابگر ساعت
          if (_isSharedTime) ...[
            InkWell(
              onTap: () => _pickTimeForDay(null),
              borderRadius: BorderRadius.circular(RitmoRadius.field),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.md,
                  vertical: RitmoSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ساعت شروع جلسات:',
                      style: RitmoTextStyles.body(colors.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sportsColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(RitmoRadius.badge),
                      ),
                      child: Text(
                        toPersianDigits(_sharedTime),
                        style: RitmoTextStyles.titleMedium(sportsColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Column(
              children: _selectedDaysWithTime.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: RitmoSpacing.xs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RitmoSpacing.md,
                      vertical: RitmoSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _weekdayFullNames[e.key],
                          style: RitmoTextStyles.body(colors.textPrimary),
                        ),
                        TextButton(
                          onPressed: () => _pickTimeForDay(e.key),
                          child: Text(
                            toPersianDigits(e.value),
                            style: RitmoTextStyles.titleMedium(sportsColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: RitmoSpacing.lg),

          // انتخاب دورهٔ تکرار (هفتگی پیوسته / تک‌جلسه / ۴ هفته)
          Text(
            'مدت اعتبار برنامه:',
            style: RitmoTextStyles.body(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.xs),
          Wrap(
            spacing: RitmoSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text(MovementStrings.recurrenceWeekly),
                selected: _recurrence == 'weekly',
                selectedColor: sportsColor,
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _recurrence = 'weekly');
                    _notifyChanges();
                  }
                },
              ),
              ChoiceChip(
                label: const Text(MovementStrings.recurrenceOnce),
                selected: _recurrence == 'once',
                selectedColor: sportsColor,
                onSelected: (sel) {
                  if (sel) {
                    setState(() => _recurrence = 'once');
                    _notifyChanges();
                  }
                },
              ),
              ChoiceChip(
                label: const Text(MovementStrings.recurrence4Weeks),
                selected: _recurrence == 'nWeeks',
                selectedColor: sportsColor,
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _recurrence = 'nWeeks';
                      _weeksCount = 4;
                    });
                    _notifyChanges();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
