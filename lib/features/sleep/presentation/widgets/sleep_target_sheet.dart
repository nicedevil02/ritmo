import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/services/sleep_winddown_reminder_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/sleep/data/sleep_program_repository.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:sqflite/sqflite.dart';

class SleepTargetSheet extends StatefulWidget {

  const SleepTargetSheet({
    super.key,
    required this.onSaved,
    this.currentTarget,
    this.isWinddownEnabled = false,
    this.winddownMinutes = 30,
  });
  final VoidCallback onSaved;
  final SleepTarget? currentTarget;
  final bool isWinddownEnabled;
  final int winddownMinutes;

  @override
  State<SleepTargetSheet> createState() => _SleepTargetSheetState();
}

class _SleepTargetSheetState extends State<SleepTargetSheet> {
  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 30);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  int _targetDuration = 450; // 7.5 hours
  bool _winddownEnabled = false;
  int _winddownMinutes = 30;
  int? _freeNightWeekday;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.currentTarget != null) {
      _bedtime = TimeOfDay(hour: widget.currentTarget!.bedtimeHour, minute: widget.currentTarget!.bedtimeMinute);
      _wakeTime = TimeOfDay(hour: widget.currentTarget!.wakeHour, minute: widget.currentTarget!.wakeMinute);
      _targetDuration = widget.currentTarget!.durationMinutes;
    } else {
      _recalculateDuration();
    }
    _winddownEnabled = widget.isWinddownEnabled;
    _winddownMinutes = widget.winddownMinutes;
    _loadFreeNightWeekday();
  }

  Future<void> _loadFreeNightWeekday() async {
    try {
      final repo = await SleepProgramRepository.fromHelper();
      final program = await repo.currentProgram();
      if (mounted && program != null) {
        setState(() {
          _freeNightWeekday = program.freeNightWeekday;
        });
      }
    } catch (_) {}
  }

  void _recalculateDuration() {
    // Difference between bedtime and wake time
    final btMin = _bedtime.hour * 60 + _bedtime.minute;
    final wtMin = _wakeTime.hour * 60 + _wakeTime.minute;

    var diff = wtMin - btMin;
    if (diff <= 0) {
      diff += 1440; // Sleep crosses midnight
    }

    setState(() {
      _targetDuration = diff;
    });
  }

  Future<void> _selectBedtime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _bedtime,
      cancelText: 'انصراف',
      confirmText: 'تایید',
      helpText: 'ساعت خواب هدف',
    );
    if (picked != null) {
      setState(() {
        _bedtime = picked;
      });
      _recalculateDuration();
    }
  }

  Future<void> _selectWakeTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _wakeTime,
      cancelText: 'انصراف',
      confirmText: 'تایید',
      helpText: 'ساعت بیداری هدف',
    );
    if (picked != null) {
      setState(() {
        _wakeTime = picked;
      });
      _recalculateDuration();
    }
  }

  Future<void> _saveTargets() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final bedtimeStr = '${_bedtime.hour.toString().padLeft(2, '0')}:${_bedtime.minute.toString().padLeft(2, '0')}';
      final wakeStr = '${_wakeTime.hour.toString().padLeft(2, '0')}:${_wakeTime.minute.toString().padLeft(2, '0')}';

      final settings = {
        'sleep_target_bedtime': bedtimeStr,
        'sleep_target_wake': wakeStr,
        'sleep_target_duration_minutes': _targetDuration.toString(),
        'sleep_winddown_reminder': _winddownEnabled.toString(),
        'sleep_winddown_minutes': _winddownMinutes.toString(),
        'sleep_setup_done': 'true',
        'module_sleep_enabled': 'true',
      };

      for (final entry in settings.entries) {
        await db.insert(
          'app_settings',
          {
            'key': entry.key,
            'value': entry.value,
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // قدم صفر: یادآور پیش‌خواب حالا واقعاً خوانده و زمان‌بندی می‌شود
      await SleepWinddownReminderService.syncFromSettings();

      // شب آزاد در برنامهٔ خواب ذخیره می‌شود
      final repo = await SleepProgramRepository.fromHelper();
      await repo.setFreeNightWeekday(_freeNightWeekday);

      // Fire event to invalidate cache
      RitmoEventBus().fire(RitmoEvent(
        type: 'SleepLogged', // reuse to trigger cache refresh
        timestamp: DateTime.now(),
        payload: {},
      ));

      RitmoEventBus().fire(RitmoEvent(
        type: 'SleepTargetUpdated',
        timestamp: DateTime.now(),
        payload: {
          'bedtime': bedtimeStr,
          'wake': wakeStr,
        },
      ));

      await HapticFeedback.mediumImpact();
      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اهداف خواب شما با موفقیت ذخیره شدند 🌙', style: TextStyle()),
            backgroundColor: Color(0xff8B5CF6),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving sleep targets: $e');
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hours = _targetDuration ~/ 60;
    final minutes = _targetDuration % 60;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoTheme.glassCardLight(
        borderRadius: 28,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'تنظیم اهداف خواب و بیداری',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.cardTitle),
                    ),
                    IconButton(
                      icon: Icon(CupertinoIcons.xmark, color: colors.iconSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ساعات ایده‌آل و مورد نظر خود را برای خواب و بیداری منظم مشخص کنید.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 20),

                // Selectors
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectBedtime,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.cardFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ساعت خواب هدف', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                              const SizedBox(height: 6),
                              Text(
                                '${_bedtime.hour.toString().padLeft(2, '0')}:${_bedtime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.cardTitle),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _selectWakeTime,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.cardFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.glassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ساعت بیداری هدف', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                              const SizedBox(height: 6),
                              Text(
                                '${_wakeTime.hour.toString().padLeft(2, '0')}:${_wakeTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.cardTitle),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Target Duration Adjuster
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.cardFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مدت زمان خواب هدف:',
                            style: TextStyle(fontSize: 13, color: colors.cardTitle),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hours > 0 ? '$hours ساعت و $minutes دقیقه' : '$minutes دقیقه',
                            style: TextStyle(fontSize: 11, color: colors.textSecondary),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(CupertinoIcons.minus_circle, color: colors.iconSecondary),
                            onPressed: _targetDuration > 240 // Minimum 4 hours
                                ? () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _targetDuration -= 15);
                                  }
                                : null,
                          ),
                          Text(
                            '$_targetDuration د',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.cardTitle),
                          ),
                          IconButton(
                            icon: Icon(CupertinoIcons.plus_circle, color: colors.iconSecondary),
                            onPressed: _targetDuration < 720 // Maximum 12 hours
                                ? () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _targetDuration += 15);
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Winddown Switch
                SwitchListTile(
                  title: Text(
                    'یادآور پیش‌خواب (Wind-down)',
                    style: TextStyle(fontSize: 13, color: colors.cardTitle),
                  ),
                  subtitle: Text(
                    'ارسال اعلان ملایم برای آماده‌شدن جهت خواب',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                  value: _winddownEnabled,
                  activeThumbColor: const Color(0xff8B5CF6),
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _winddownEnabled = val;
                    });
                  },
                ),
                if (_winddownEnabled) ...[
                  const SizedBox(height: 10),
                  Text(
                    'زمان یادآوری: $_winddownMinutes دقیقه قبل از خواب',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  Slider(
                    value: _winddownMinutes.toDouble(),
                    min: 15,
                    max: 120,
                    divisions: 7,
                    activeColor: const Color(0xff8B5CF6),
                    inactiveColor: colors.glassBorder,
                    label: '$_winddownMinutes دقیقه',
                    onChanged: (val) {
                      setState(() {
                        _winddownMinutes = val.toInt();
                      });
                    },
                  ),
                ],
                const SizedBox(height: 20),

                // Free night ChoiceChip
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'شب آزاد هفتگی',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.cardTitle),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'یک شب در هفته که برنامه هیچ انتظاری از شما ندارد و از سنجش پایبندی حذف می‌شود.',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('بدون شب آزاد', style: TextStyle(fontSize: 12)),
                            selected: _freeNightWeekday == null,
                            selectedColor: const Color(0xff8B5CF6).withValues(alpha: 0.2),
                            onSelected: (selected) {
                              if (selected) {
                                HapticFeedback.selectionClick();
                                setState(() => _freeNightWeekday = null);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ...[
                            {'day': DateTime.saturday, 'name': 'شنبه'},
                            {'day': DateTime.sunday, 'name': 'یکشنبه'},
                            {'day': DateTime.monday, 'name': 'دوشنبه'},
                            {'day': DateTime.tuesday, 'name': 'سه‌شنبه'},
                            {'day': DateTime.wednesday, 'name': 'چهارشنبه'},
                            {'day': DateTime.thursday, 'name': 'پنج‌شنبه'},
                            {'day': DateTime.friday, 'name': 'جمعه'},
                          ].map((w) {
                            final day = w['day'] as int;
                            final name = w['name'] as String;
                            final isSelected = _freeNightWeekday == day;
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: ChoiceChip(
                                label: Text(name, style: TextStyle(fontSize: 12, color: isSelected ? const Color(0xff8B5CF6) : colors.textPrimary)),
                                selected: isSelected,
                                selectedColor: const Color(0xff8B5CF6).withValues(alpha: 0.2),
                                onSelected: (selected) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _freeNightWeekday = selected ? day : null);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Save button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSaving ? null : _saveTargets,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'ذخیره اهداف خواب',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
