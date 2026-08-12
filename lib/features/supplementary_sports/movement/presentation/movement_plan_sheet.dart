// lib/features/supplementary_sports/movement/presentation/movement_plan_sheet.dart
//
// فاز ۲ — مسیر برنامه‌ریزی با روتین
// این شیت برای ساخت و ویرایش روتین‌های ورزشی تکرارشونده استفاده می‌شود.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/features/routines/domain/routine_recurrence.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/movement_kind_selector.dart';
import 'package:ritmo/features/routines/presentation/widgets/planner_day_of_week_selector.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_tokens.dart';

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

  MovementKind? _selectedKind;
  List<int> _selectedDays = [6, 7, 1, 2, 3, 4, 5]; // Default: all days
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  bool _hasReminder = true;
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
    _initFromRoutine();
  }

  Future<void> _initFromRoutine() async {
    final toEdit = widget.routineToEdit;
    if (toEdit == null) {
      // Default initialization
      return;
    }

    final kindCode = toEdit['movementKind']?.toString() ?? 'WALKING';
    final kinds = await MovementRepository.instance.getKinds(enabledOnly: false);
    final matchingKind = kinds.firstWhere(
      (k) => k.code == kindCode,
      orElse: () => kinds.isNotEmpty ? kinds.first : _fallbackKind(),
    );

    // Days extraction
    final daysStr = toEdit['daysOfWeek']?.toString() ?? '';
    List<int> days = [];
    if (daysStr.isNotEmpty) {
      days = daysStr.split(',').map((s) => int.parse(s.trim())).toList();
    } else {
      days = [6, 7, 1, 2, 3, 4, 5];
    }

    // TimeOfDay extraction
    final timeStr = toEdit['timeOfDay']?.toString() ?? '07:00';
    final parts = timeStr.split(':');
    final time = parts.length == 2
        ? TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]))
        : const TimeOfDay(hour: 7, minute: 0);

    // Targets
    final targetVal = (toEdit['movementTargetValue'] as num? ?? 30.0).toDouble();
    final duration = (toEdit['targetDurationMinutes'] as num? ?? 30).toInt();

    setState(() {
      _selectedKind = matchingKind;
      _selectedDays = days;
      _selectedTime = time;
      _hasReminder = (toEdit['reminderOffsetMinutes'] as num? ?? 15) > 0;
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

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
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
        const SnackBar(content: Text('حداقل یک روز در هفته را انتخاب کن', style: TextStyle(fontFamily: 'Vazirmatn'))),
      );
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now().millisecondsSinceEpoch;

    final routineId = _isEditing
        ? widget.routineToEdit!['id'] as String
        : RitmoIdFactory.routine();

    final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final targetValue = _getTargetValue();

    final routineData = {
      'id': routineId,
      'title': _selectedKind!.titleFa,
      'description': _isEditing ? widget.routineToEdit!['description'] : null,
      'category': 'fitness',
      'customCategoryId': null,
      'zoneId': _isEditing ? widget.routineToEdit!['zoneId'] : null,
      'routineType': 'ROUTINE',
      'notificationLevel': 'NORMAL',
      'isEssential': 0,
      'isEssentialLocked': 0,
      'energyRule': 'NONE',
      'priority': 1.0,
      'targetDurationMinutes': _durationMinutes,
      'lightDurationMinutes': 0,
      'minimalDurationMinutes': 0,
      'isArchived': 0,
      'isPrivate': 0,
      'displayOrder': 1,
      'createdAt': _isEditing ? widget.routineToEdit!['createdAt'] ?? now : now,
      'updatedAt': now,
      'dependsOnRoutineId': null,
      'itemType': 'ROUTINE',
      'reminderOffsetMinutes': _hasReminder ? 15 : 0,
      'movementKind': _selectedKind!.code,
      'movementTargetMetric': _selectedKind!.primaryMetric.name.toUpperCase(),
      'movementTargetValue': targetValue,
      'movementIsMeetup': 0,
    };

    final recurrence = WeekdaysRecurrence(weekdays: _selectedDays.toSet());
    final (schedType, daysOfWeek) = deriveScheduleParams(recurrence);
    final recurrenceJson = encodeRecurrenceRule(
      recurrence: recurrence,
      startDate: DateTime.now(),
      reminderTimes: [timeStr],
    );

    final scheduleData = {
      'id': RitmoIdFactory.schedule(routineId),
      'routineId': routineId,
      'scheduleType': schedType,
      'timeOfDay': timeStr,
      'daysOfWeek': daysOfWeek,
      'recurrenceRule': recurrenceJson,
      'createdAt': _isEditing ? widget.routineToEdit!['createdAt'] ?? now : now,
      'updatedAt': now,
    };

    try {
      if (_isEditing) {
        await RitmoExecutionKernel.instance.execute(
          EditRoutineCommand(
            routineId: routineId,
            routineData: routineData,
            scheduleData: scheduleData,
            applyToAll: true,
          ),
        );
      } else {
        await RitmoExecutionKernel.instance.execute(
          CreateRoutineCommand(
            routineData: routineData,
            scheduleData: scheduleData,
          ),
        );
      }
      
      if (!_isEditing) {
        RitmoEventBus().fire(RitmoEvent(
          type: 'movement_plan_created',
          timestamp: DateTime.now(),
          payload: {
            'kindCode': _selectedKind?.code,
          },
        ));
      }

      RitmoHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'برنامه با موفقیت ویرایش شد ✨' : 'برنامهٔ حرکتی جدید با موفقیت ایجاد شد ✨',
              style: const TextStyle(fontFamily: 'Vazirmatn'),
            ),
          ),
        );
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ذخیره برنامه: $e', style: const TextStyle(fontFamily: 'Vazirmatn'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _archivePlan() async {
    if (!_isEditing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('آرشیو برنامه', style: TextStyle(fontFamily: 'Vazirmatn')),
        content: const Text('این برنامه به آرشیو منتقل شده و از اجندا حذف می‌شود. مطمئنی؟', style: TextStyle(fontFamily: 'Vazirmatn')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف', style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('بله، آرشیو کن', style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final routineId = widget.routineToEdit!['id'] as String;
      await RitmoExecutionKernel.instance.execute(
        ArchiveRoutineCommand(routineId: routineId),
      );
      RitmoHaptics.success();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('برنامه آرشیو شد 📥', style: TextStyle(fontFamily: 'Vazirmatn'))),
        );
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در آرشیو برنامه: $e', style: const TextStyle(fontFamily: 'Vazirmatn'))),
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
    final timeLabel = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}'.toPersianDigits();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            // Top Drag Handle
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'ویرایش برنامهٔ حرکت' : 'برنامه‌ریزی حرکت جدید',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Form Fields
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: 20 + bottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Selector
                    MovementKindSelector(
                      selectedKind: _selectedKind,
                      onKindSelected: (k) => setState(() => _selectedKind = k),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    if (_selectedKind != null) ...[
                      // 2. Target metric sliders
                      Text(
                        'هدف برنامه‌ریزی: ${_selectedKind!.emoji} ${_selectedKind!.titleFa}',
                        style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 14, color: colors.primary),
                      ),
                      const SizedBox(height: 16),

                      // Duration slider (always needed for targetDurationMinutes)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('مدت زمان هدف:', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
                          Text(
                            '${_durationMinutes.toPersianDigits()} دقیقه',
                            style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, color: colors.primary, fontSize: 16),
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
                      const SizedBox(height: 12),

                      // Other metrics
                      if (_selectedKind!.primaryMetric == MovementMetric.distance) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('مسافت هدف (کیلومتر):', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
                            Text('${_distanceKm.toStringAsFixed(1).toPersianDigits()} km', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, color: colors.primary)),
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
                        const SizedBox(height: 12),
                      ] else if (_selectedKind!.primaryMetric == MovementMetric.laps) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('تعداد طول هدف (استخر ۲۵ متری):', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
                            Text('${_laps.toPersianDigits()} طول (${(_laps * 25).toPersianDigits()} متر)', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, color: colors.primary)),
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
                        const SizedBox(height: 12),
                      ] else if (_selectedKind!.primaryMetric == MovementMetric.elevation) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('ارتفاع هدف (متر):', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
                            Text('${_elevationMeters.toInt().toPersianDigits()} متر', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, color: colors.primary)),
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
                        const SizedBox(height: 12),
                      ] else if (_selectedKind!.primaryMetric == MovementMetric.steps) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('تعداد گام هدف:', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
                            Text('${_steps.toPersianDigits()} گام', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, color: colors.primary)),
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
                        const SizedBox(height: 12),
                      ],

                      const Divider(),
                      const SizedBox(height: 16),
                    ],

                    // 3. Days Selection
                    const Text(
                      'روزهای اجرای برنامه در هفته:',
                      style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    PlannerDayOfWeekSelector(
                      selectedDays: _selectedDays,
                      onChanged: (days) => setState(() => _selectedDays = days),
                    ),
                    const SizedBox(height: 24),

                    // 4. Time Picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'ساعت شروع تمرین:',
                        style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          timeLabel,
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      onTap: _selectTime,
                    ),
                    const SizedBox(height: 12),

                    // 5. Reminder Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'یادآوری قبل از شروع',
                        style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        '۱۵ دقیقه قبل از زمان برنامه‌ریزی‌شده مطلع شو',
                        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
                      ),
                      value: _hasReminder,
                      activeThumbColor: CalendarTokens.emerald,
                      activeTrackColor: CalendarTokens.emerald.withValues(alpha: 0.5),
                      onChanged: (val) => setState(() => _hasReminder = val),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Buttons Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E2630)
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (_isEditing) ...[
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isSaving ? null : _archivePlan,
                          icon: const Icon(CupertinoIcons.archivebox_fill, color: Colors.redAccent, size: 18),
                          label: const Text(
                            'آرشیو برنامه',
                            style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_selectedKind == null || _isSaving)
                              ? Theme.of(context).disabledColor.withValues(alpha: 0.15)
                              : CalendarTokens.emerald,
                          disabledBackgroundColor: Theme.of(context).disabledColor.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: (_selectedKind == null || _isSaving) ? null : _savePlan,
                        child: _isSaving
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : Text(
                                _isEditing ? 'ذخیره تغییرات' : 'ایجاد برنامهٔ حرکت',
                                style: const TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
