import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/services/sleep_winddown_reminder_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
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
      _bedtime = TimeOfDay(
        hour: widget.currentTarget!.bedtimeHour,
        minute: widget.currentTarget!.bedtimeMinute,
      );
      _wakeTime = TimeOfDay(
        hour: widget.currentTarget!.wakeHour,
        minute: widget.currentTarget!.wakeMinute,
      );
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

      final bedtimeStr =
          '${_bedtime.hour.toString().padLeft(2, '0')}:${_bedtime.minute.toString().padLeft(2, '0')}';
      final wakeStr =
          '${_wakeTime.hour.toString().padLeft(2, '0')}:${_wakeTime.minute.toString().padLeft(2, '0')}';

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

      await SleepWinddownReminderService.syncFromSettings();

      final programRepo = await SleepProgramRepository.fromHelper();
      await programRepo.setFreeNightWeekday(_freeNightWeekday);

      RitmoEventBus().fire(RitmoEvent(
        type: 'SleepTargetUpdated',
        timestamp: DateTime.now(),
        payload: {
          'bedtime': bedtimeStr,
          'wake': wakeStr,
          'durationMinutes': _targetDuration,
        },
      ));

      await HapticFeedback.mediumImpact();
      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'اهداف خواب شما با موفقیت ذخیره شدند 🌙',
              style: TextStyle(),
            ),
            backgroundColor: context.colors.sleepAccent,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ساعات ایده‌آل و مورد نظر خود را برای خواب و بیداری منظم مشخص کنید.',
          style: RitmoTextStyles.caption(colors.textSecondary),
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // Selectors
        Row(
          children: [
            Expanded(
              child: RitmoCard.neumorphic(
                onTap: _selectBedtime,
                padding: const EdgeInsets.all(RitmoSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.moon_stars_fill, size: 14, color: colors.sleepAccent),
                        const SizedBox(width: 6),
                        Text(
                          'ساعت خواب هدف',
                          style: RitmoTextStyles.caption(colors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${RitmoNumber.faInt(_bedtime.hour).padLeft(2, '۰')}:${RitmoNumber.faInt(_bedtime.minute).padLeft(2, '۰')}',
                      style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: RitmoSpacing.md),
            Expanded(
              child: RitmoCard.neumorphic(
                onTap: _selectWakeTime,
                padding: const EdgeInsets.all(RitmoSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(CupertinoIcons.sun_max_fill, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        Text(
                          'ساعت بیداری هدف',
                          style: RitmoTextStyles.caption(colors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${RitmoNumber.faInt(_wakeTime.hour).padLeft(2, '۰')}:${RitmoNumber.faInt(_wakeTime.minute).padLeft(2, '۰')}',
                      style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.md),

        // Target Duration Adjuster
        RitmoCard.neumorphic(
          padding: const EdgeInsets.all(RitmoSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مدت زمان خواب هدف:',
                    style: RitmoTextStyles.titleMedium(colors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hours > 0
                        ? '${RitmoNumber.faInt(hours)} ساعت ${minutes > 0 ? 'و ${RitmoNumber.faInt(minutes)} دقیقه' : ''}'
                        : '${RitmoNumber.faInt(minutes)} دقیقه',
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(CupertinoIcons.minus_circle, color: colors.textSecondary),
                    onPressed: _targetDuration > 240
                        ? () {
                            HapticFeedback.lightImpact();
                            setState(() => _targetDuration -= 15);
                          }
                        : null,
                  ),
                  Text(
                    '${RitmoNumber.faInt(_targetDuration)} د',
                    style: RitmoTextStyles.label(colors.textPrimary),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.plus_circle, color: colors.textSecondary),
                    onPressed: _targetDuration < 720
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
        const SizedBox(height: RitmoSpacing.md),

        // Winddown Switch
        RitmoCard.neumorphic(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'یادآور پیش‌خواب (Wind-down)',
                  style: RitmoTextStyles.titleMedium(colors.textPrimary),
                ),
                subtitle: Text(
                  'ارسال اعلان ملایم برای آماده‌شدن جهت خواب',
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
                value: _winddownEnabled,
                activeThumbColor: colors.sleepAccent,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _winddownEnabled = val;
                  });
                },
              ),
              if (_winddownEnabled) ...[
                const SizedBox(height: 4),
                Text(
                  'زمان یادآوری: ${RitmoNumber.faInt(_winddownMinutes)} دقیقه قبل از خواب',
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
                Slider(
                  value: _winddownMinutes.toDouble(),
                  min: 15,
                  max: 120,
                  divisions: 7,
                  activeColor: colors.sleepAccent,
                  inactiveColor: colors.border,
                  label: '${RitmoNumber.faInt(_winddownMinutes)} دقیقه',
                  onChanged: (val) {
                    setState(() {
                      _winddownMinutes = val.toInt();
                    });
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: RitmoSpacing.md),

        // Free night ChoiceChip
        RitmoCard.neumorphic(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'شب آزاد هفتگی',
                style: RitmoTextStyles.titleMedium(colors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'یک شب در هفته که برنامه هیچ انتظاری از شما ندارد و از سنجش پایبندی حذف می‌شود.',
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(
                        'بدون شب آزاد',
                        style: RitmoTextStyles.caption(
                          _freeNightWeekday == null ? colors.onPrimary : colors.textPrimary,
                        ),
                      ),
                      selected: _freeNightWeekday == null,
                      selectedColor: colors.sleepAccent,
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
                          label: Text(
                            name,
                            style: RitmoTextStyles.caption(
                              isSelected ? colors.onPrimary : colors.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: colors.sleepAccent,
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
        ),
        const SizedBox(height: RitmoSpacing.xl),

        // Save button
        RitmoPrimaryButton(
          label: 'ذخیره اهداف خواب',
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _saveTargets,
        ),
      ],
    );
  }
}
