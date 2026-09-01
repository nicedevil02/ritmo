import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/progression_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/services/ritmo_timer_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/today/presentation/active_timer_overlay.dart';
import 'package:sqflite/sqflite.dart';

/// Specialized Action Sheet for Progressive Routines (RoutineType.progressive / Atomic Habits)
class RoutineProgressiveSheet extends StatefulWidget {
  const RoutineProgressiveSheet({
    super.key,
    required this.routine,
    required this.targetDate,
    this.onChanged,
  });

  final Routine routine;
  final String targetDate;
  final VoidCallback? onChanged;

  static Future<void> show({
    required BuildContext context,
    required Routine routine,
    required String targetDate,
    VoidCallback? onChanged,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoutineProgressiveSheet(
        routine: routine,
        targetDate: targetDate,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<RoutineProgressiveSheet> createState() => _RoutineProgressiveSheetState();
}

class _RoutineProgressiveSheetState extends State<RoutineProgressiveSheet> {
  int _currentMinutes = 5;
  int _targetMinutes = 30;
  int _step = 2;
  int _everyN = 7;
  int _doneSinceAdvance = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentMinutes = widget.routine.currentTargetMinutes > 0
        ? widget.routine.currentTargetMinutes
        : (widget.routine.progressionStart > 0 ? widget.routine.progressionStart : 5);
    _targetMinutes = widget.routine.progressionTarget > 0 ? widget.routine.progressionTarget : 30;
    _step = widget.routine.progressionStep > 0 ? widget.routine.progressionStep : 2;
    _everyN = widget.routine.progressionEveryN > 0 ? widget.routine.progressionEveryN : 7;
    _doneSinceAdvance = widget.routine.progressionDoneSinceAdvance;
  }

  Future<void> _completeProgression() async {
    if (_isSaving) return;
    _isSaving = true;
    RitmoHaptics.confirm();

    final now = DateTime.now();
    try {
      final db = await DatabaseHelper.instance.database;

      await db.insert(
        'routine_occurrences',
        {
          'routine_id': widget.routine.id,
          'date': widget.targetDate,
          'status': 'completed',
          'target_duration_minutes': _currentMinutes,
          'actual_duration_minutes': _currentMinutes,
          'completed_at': now.millisecondsSinceEpoch,
          'notes': 'انجام شد با مدت $_currentMinutes دقیقه',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final engine = ProgressionEngine();
      await engine.onCompletion(db, widget.routine.id, CompletionResult.full);

      DayAgendaService.instance.invalidateDate(widget.targetDate);
      RitmoEvents.notifyRoutineChanged();
      RitmoEventBus().fire(RitmoEvent(
        type: 'RoutineUpdated',
        timestamp: now,
        payload: {
          'routineId': widget.routine.id,
          'date': widget.targetDate,
        },
      ));

      if (mounted) {
        Navigator.pop(context);
        widget.onChanged?.call();
      }
    } catch (e) {
      debugPrint('Error completing progressive routine: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _startTimer() {
    RitmoHaptics.confirm();
    Navigator.pop(context);

    RitmoTimerService.instance.startTimer(
      id: 'routine_${widget.routine.id}',
      domain: 'routine',
      itemId: widget.routine.id,
      mode: 'FULL',
      durationMinutes: _currentMinutes,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ActiveTimerOverlay(
          routine: widget.routine,
          completionMode: 'FULL',
          dateStr: widget.targetDate,
          onCompleted: (outcome) {
            Navigator.pop(ctx);
            DayAgendaService.instance.invalidateDate(widget.targetDate);
            widget.onChanged?.call();
          },
          onCancelled: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final progressToNext = (_doneSinceAdvance / _everyN).clamp(0.0, 1.0);
    final remainingDays = _everyN - _doneSinceAdvance;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoGlassSheet(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: isDark ? 0.30 : 0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Header
            Text(
              widget.routine.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'عادت تدریجی و پیش‌رونده',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: 20),

            // Current Level & Target Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262B36) : const Color(0xFFF4F6F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'هدف سطح امروز:',
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${toPersianDigits(_currentMinutes.toString())} دقیقه',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'هدف نهایی: ${toPersianDigits(_targetMinutes.toString())} دقیقه',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress to Next Level
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'پیشرفت صعود به مرحله بعد:',
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                          Text(
                            '${toPersianDigits(_doneSinceAdvance.toString())} از ${toPersianDigits(_everyN.toString())} روز',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressToNext,
                          minHeight: 8,
                          backgroundColor: colors.border.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'با $remainingDays بار اجرای دیگر، زمان به ${toPersianDigits((_currentMinutes + _step).toString())} دقیقه ارتقا می‌یابد 🚀',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startTimer,
                    icon: const Icon(Icons.timer_outlined, size: 18),
                    label: const Text('شروع تایمر'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: colors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _completeProgression,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('ثبت انجام شد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
