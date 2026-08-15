import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/services/ritmo_timer_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/today/presentation/active_timer_overlay.dart';
import 'package:sqflite/sqflite.dart';

/// Specialized Action Sheet for As-Needed Routines (RoutineType.asNeeded / PRN)
class RoutineAsNeededSheet extends StatefulWidget {
  const RoutineAsNeededSheet({
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
      builder: (context) => RoutineAsNeededSheet(
        routine: routine,
        targetDate: targetDate,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<RoutineAsNeededSheet> createState() => _RoutineAsNeededSheetState();
}

class _RoutineAsNeededSheetState extends State<RoutineAsNeededSheet> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  Future<void> _logNow() async {
    if (_isSaving) return;
    _isSaving = true;
    RitmoHaptics.confirm();

    final now = DateTime.now();
    try {
      final db = await DatabaseHelper.instance.database;
      final note = _noteController.text.trim();

      await db.insert(
        'routine_occurrences',
        {
          'routine_id': widget.routine.id,
          'date': widget.targetDate,
          'status': 'completed',
          'target_duration_minutes': widget.routine.targetDurationMinutes ?? 10,
          'actual_duration_minutes': widget.routine.targetDurationMinutes ?? 10,
          'completed_at': now.millisecondsSinceEpoch,
          'notes': note.isNotEmpty ? note : 'ثبت برحسب نیاز',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

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
      debugPrint('Error logging as-needed routine: $e');
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
      durationMinutes: widget.routine.targetDurationMinutes ?? 15,
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
    final duration = widget.routine.targetDurationMinutes ?? 15;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

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
              'فعالیت آزاد و برحسب نیاز (PRN)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: 18),

            // Note Input
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'یادداشت یا علت ثبت (اختیاری)...',
                hintStyle: TextStyle(fontSize: 12, color: colors.textTertiary),
                filled: true,
                fillColor: isDark ? const Color(0xFF262B36) : const Color(0xFFF4F6F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border.withValues(alpha: 0.2)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              children: [
                if (duration > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _startTimer,
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: Text('تایمر (${toPersianDigits(duration.toString())} د)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: colors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _logNow,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('ثبت اکنون ✓'),
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
