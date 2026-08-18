import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:sqflite/sqflite.dart';

class SleepLogSheet extends StatefulWidget {
  const SleepLogSheet({
    super.key,
    required this.onSaved,
    required this.target,
  });
  final VoidCallback onSaved;
  final SleepTarget target;

  @override
  State<SleepLogSheet> createState() => _SleepLogSheetState();
}

class _SleepLogSheetState extends State<SleepLogSheet> {
  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 30);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  SleepQuality _quality = SleepQuality.good;
  int _awakenings = 0;
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;
  bool _showWorkoutWarning = false;

  @override
  void initState() {
    super.initState();
    _bedtime = TimeOfDay(hour: widget.target.bedtimeHour, minute: widget.target.bedtimeMinute);
    _wakeTime = TimeOfDay(hour: widget.target.wakeHour, minute: widget.target.wakeMinute);
    _checkLateWorkout();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _checkLateWorkout() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr = RitmoDate.dayKey(yesterday);

      final workouts = await db.query(
        'ss_session_set_log',
        where: 'date = ?',
        whereArgs: [yesterdayStr],
        orderBy: 'timestamp DESC',
        limit: 1,
      );

      if (workouts.isNotEmpty && mounted) {
        final lastWorkoutTime = workouts.first['timestamp'] as int?;
        if (lastWorkoutTime != null) {
          final workoutDateTime = DateTime.fromMillisecondsSinceEpoch(lastWorkoutTime);
          if (workoutDateTime.hour >= 20) {
            setState(() {
              _showWorkoutWarning = true;
            });
          }
        }
      }
    } catch (_) {}
  }

  Map<String, dynamic> _calculateTimes() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    var bedtimeDt = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
      _bedtime.hour,
      _bedtime.minute,
    );

    var wakeDt = DateTime(
      now.year,
      now.month,
      now.day,
      _wakeTime.hour,
      _wakeTime.minute,
    );

    if (_bedtime.hour < 12) {
      bedtimeDt = DateTime(
        now.year,
        now.month,
        now.day,
        _bedtime.hour,
        _bedtime.minute,
      );
    }

    if (wakeDt.isBefore(bedtimeDt)) {
      wakeDt = wakeDt.add(const Duration(days: 1));
    }

    final durationMinutes = wakeDt.difference(bedtimeDt).inMinutes;

    return {
      'bedtimeAt': bedtimeDt.millisecondsSinceEpoch,
      'wakeAt': wakeDt.millisecondsSinceEpoch,
      'durationMinutes': durationMinutes,
    };
  }

  Future<void> _selectBedtime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _bedtime,
      cancelText: 'انصراف',
      confirmText: 'تایید',
      helpText: 'زمان خوابیدن دیشب',
    );
    if (picked != null) {
      setState(() {
        _bedtime = picked;
      });
    }
  }

  Future<void> _selectWakeTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _wakeTime,
      cancelText: 'انصراف',
      confirmText: 'تایید',
      helpText: 'زمان بیدار شدن امروز',
    );
    if (picked != null) {
      setState(() {
        _wakeTime = picked;
      });
    }
  }

  Future<void> _saveSleepLog() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = RitmoDate.dayKey(yesterday);
      final nowMs = now.millisecondsSinceEpoch;

      final times = _calculateTimes();
      final duration = times['durationMinutes'] as int;

      String? reason;
      if (duration < widget.target.durationMinutes - 60) {
        reason = 'کمبود خواب نسبت به هدف';
      } else if (duration > widget.target.durationMinutes + 60) {
        reason = 'خواب بیش از حد نسبت به هدف';
      }

      await db.insert(
        'bedtime_diagnostics',
        {
          'date': yesterdayStr,
          'reason': reason,
          'note': _noteController.text.isNotEmpty ? _noteController.text : null,
          'createdAt': nowMs,
          'bedtimeAt': times['bedtimeAt'],
          'wakeAt': times['wakeAt'],
          'durationMinutes': duration,
          'quality': _quality.score,
          'awakenings': _awakenings,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      var energyLevel = 'MEDIUM';
      if (_quality == SleepQuality.terrible || _quality == SleepQuality.poor) {
        energyLevel = 'LOW';
      } else if (_quality == SleepQuality.good || _quality == SleepQuality.excellent) {
        energyLevel = 'HIGH';
      }

      await db.insert(
        'app_settings',
        {
          'key': 'default_energy_level',
          'value': energyLevel,
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      RitmoEventBus().fire(RitmoEvent(
        type: 'SleepLogged',
        timestamp: DateTime.now(),
        payload: {
          'date': yesterdayStr,
          'quality': _quality.score,
          'durationMinutes': duration,
        },
      ));

      await HapticFeedback.mediumImpact();
      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('خواب دیشب شما با موفقیت ثبت شد 🌿', style: TextStyle()),
            backgroundColor: context.colors.sleepAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving sleep log: $e');
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
    final times = _calculateTimes();
    final durationMin = times['durationMinutes'] as int;
    final hours = durationMin ~/ 60;
    final minutes = durationMin % 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ساعات خواب و بیداری دیشب را مشخص کنید.',
          style: RitmoTextStyles.caption(colors.textSecondary),
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // Bedtime & Wake time selectors
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _selectBedtime,
                borderRadius: BorderRadius.circular(RitmoRadius.card),
                child: Container(
                  padding: const EdgeInsets.all(RitmoSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'زمان خوابیدن',
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${RitmoNumber.faInt(_bedtime.hour).padLeft(2, '۰')}:${RitmoNumber.faInt(_bedtime.minute).padLeft(2, '۰')}',
                        style: RitmoTextStyles.cardTitle(colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: RitmoSpacing.md),
            Expanded(
              child: InkWell(
                onTap: _selectWakeTime,
                borderRadius: BorderRadius.circular(RitmoRadius.card),
                child: Container(
                  padding: const EdgeInsets.all(RitmoSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'زمان بیدار شدن',
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${RitmoNumber.faInt(_wakeTime.hour).padLeft(2, '۰')}:${RitmoNumber.faInt(_wakeTime.minute).padLeft(2, '۰')}',
                        style: RitmoTextStyles.cardTitle(colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.md),

        // Calculated Duration Card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: colors.sleepAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            border: Border.all(color: colors.sleepAccent.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مدت زمان محاسبه‌شده:',
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
              Text(
                hours > 0
                    ? '${RitmoNumber.faInt(hours)} ساعت ${minutes > 0 ? 'و ${RitmoNumber.faInt(minutes)} دقیقه' : ''}'
                    : '${RitmoNumber.faInt(minutes)} دقیقه',
                style: RitmoTextStyles.label(colors.sleepAccent),
              ),
            ],
          ),
        ),
        if (_showWorkoutWarning) ...[
          const SizedBox(height: RitmoSpacing.md),
          Container(
            padding: const EdgeInsets.all(RitmoSpacing.md),
            decoration: BoxDecoration(
              color: colors.cautionAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: colors.cautionAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.exclamationmark_triangle_fill, color: colors.cautionAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تمرین سخت یا دیرهنگام دیروز ممکن است زمان به خواب رفتن شما را با تاخیر مواجه کرده باشد. 💤',
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: RitmoSpacing.lg),

        // Sleep Quality Selector
        Text(
          'کیفیت خواب چطور بود؟',
          style: RitmoTextStyles.titleMedium(colors.textPrimary),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: SleepQuality.values.map((q) {
            final isSelected = _quality == q;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _quality = q;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.sleepAccent.withValues(alpha: 0.15)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? colors.sleepAccent : colors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(q.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        q.label,
                        style: RitmoTextStyles.caption(
                          isSelected ? colors.sleepAccent : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // Wakeups counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'دفعات بیدار شدن در شب:',
              style: RitmoTextStyles.titleMedium(colors.textPrimary),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(CupertinoIcons.minus_circle, color: colors.textSecondary),
                  onPressed: _awakenings > 0
                      ? () {
                          HapticFeedback.lightImpact();
                          setState(() => _awakenings--);
                        }
                      : null,
                ),
                Container(
                  width: 32,
                  alignment: Alignment.center,
                  child: Text(
                    RitmoNumber.faInt(_awakenings),
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.plus_circle, color: colors.textSecondary),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _awakenings++);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.md),

        // Note
        TextField(
          controller: _noteController,
          style: RitmoTextStyles.body(colors.textPrimary),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'جزئیات بیشتر یا دلیل بیداری (اختیاری)',
            hintStyle: RitmoTextStyles.caption(colors.textSecondary.withValues(alpha: 0.5)),
            fillColor: colors.surface,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              borderSide: BorderSide(color: colors.sleepAccent),
            ),
          ),
        ),
        const SizedBox(height: RitmoSpacing.xl),

        // Save button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.sleepAccent,
            foregroundColor: colors.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
            ),
          ),
          onPressed: _isSaving ? null : _saveSleepLog,
          child: _isSaving
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: colors.onPrimary,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'تایید و ثبت وضعیت خواب',
                  style: RitmoTextStyles.label(colors.onPrimary),
                ),
        ),
      ],
    );
  }
}
