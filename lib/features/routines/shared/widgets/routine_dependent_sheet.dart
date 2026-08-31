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

/// Specialized Action Sheet for Dependent Routines (RoutineType.dependent / Habit Stacking)
class RoutineDependentSheet extends StatefulWidget {
  const RoutineDependentSheet({
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
      builder: (context) => RoutineDependentSheet(
        routine: routine,
        targetDate: targetDate,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<RoutineDependentSheet> createState() => _RoutineDependentSheetState();
}

class _RoutineDependentSheetState extends State<RoutineDependentSheet> {
  Routine? _parentRoutine;
  bool _isParentCompleted = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadParentStatus();
  }

  Future<void> _loadParentStatus() async {
    final parentId = widget.routine.dependsOnRoutineId;
    if (parentId == null || parentId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final parentRows = await db.query(
        'routines',
        where: 'id = ?',
        whereArgs: [parentId],
        limit: 1,
      );

      if (parentRows.isNotEmpty) {
        _parentRoutine = Routine.fromMap(parentRows.first);
      }

      final occRows = await db.query(
        'routine_occurrences',
        where: 'routine_id = ? AND date = ?',
        whereArgs: [parentId, widget.targetDate],
        limit: 1,
      );

      if (occRows.isNotEmpty && occRows.first['status'] == 'completed') {
        _isParentCompleted = true;
      } else {
        final compRows = await db.query(
          'routine_completions',
          where: 'routineId = ? AND dateStr = ?',
          whereArgs: [parentId, widget.targetDate],
        );
        _isParentCompleted = compRows.isNotEmpty;
      }
    } catch (e) {
      debugPrint('Error loading parent routine status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _completeNow() async {
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
          'target_duration_minutes': widget.routine.targetDurationMinutes ?? 15,
          'actual_duration_minutes': widget.routine.targetDurationMinutes ?? 15,
          'completed_at': now.millisecondsSinceEpoch,
          'notes': 'تکمیل روتین زنجیره‌ای',
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
      debugPrint('Error completing dependent routine: $e');
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
    final parent = _parentRoutine;

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
        child: _isLoading
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : Column(
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
                    'روتین زنجیره‌ای (وابسته به عادت دیگر)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  // Dependency Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isParentCompleted
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isParentCompleted
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isParentCompleted
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_top_rounded,
                          color: _isParentCompleted ? Colors.green : Colors.amber,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isParentCompleted
                                    ? 'پیش‌نیاز انجام شده است ✓'
                                    : 'در انتظار انجام روتین والد',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _isParentCompleted ? Colors.green : Colors.amber.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                parent != null
                                    ? 'این روتین پس از «${parent.title}» اجرا می‌شود.'
                                    : 'روتین والد تعریف نشده یا حذف شده است.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      if (widget.routine.targetDurationMinutes != null &&
                          widget.routine.targetDurationMinutes! > 0) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _startTimer,
                            icon: const Icon(Icons.timer_outlined, size: 18),
                            label: Text(
                              'تایمر (${toPersianDigits((widget.routine.targetDurationMinutes ?? 15).toString())} دقیقه)',
                            ),
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
                          onPressed: _isSaving ? null : _completeNow,
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
