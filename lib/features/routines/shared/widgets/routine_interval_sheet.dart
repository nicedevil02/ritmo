import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:sqflite/sqflite.dart';

/// Specialized Action Sheet for Interval-based Routines (RoutineType.intervalBased)
class RoutineIntervalSheet extends StatefulWidget {
  const RoutineIntervalSheet({
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
      builder: (context) => RoutineIntervalSheet(
        routine: routine,
        targetDate: targetDate,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<RoutineIntervalSheet> createState() => _RoutineIntervalSheetState();
}

class _RoutineIntervalSheetState extends State<RoutineIntervalSheet> {
  List<DateTime> _dosesToday = [];
  bool _isLoading = true;
  bool _isSaving = false;

  int get _intervalHours => widget.routine.minIntervalHours > 0 ? widget.routine.minIntervalHours : 4;
  int get _maxDoses => widget.routine.maxDosesPerDay > 0 ? widget.routine.maxDosesPerDay : 4;

  @override
  void initState() {
    super.initState();
    _loadDoses();
  }

  Future<void> _loadDoses() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final completions = await db.query(
        'routine_completions',
        where: 'routineId = ? AND dateStr = ?',
        whereArgs: [widget.routine.id, widget.targetDate],
        orderBy: 'completedAt ASC',
      );

      final list = <DateTime>[];
      for (final row in completions) {
        final timestamp = row['completedAt'] as int?;
        if (timestamp != null) {
          list.add(DateTime.fromMillisecondsSinceEpoch(timestamp));
        }
      }

      setState(() {
        _dosesToday = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading doses for interval routine: $e');
      setState(() => _isLoading = false);
    }
  }

  DateTime? get _lastDose => _dosesToday.isNotEmpty ? _dosesToday.last : null;

  DateTime? get _nextDose => _lastDose?.add(Duration(hours: _intervalHours));

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _logDoseNow() async {
    if (_isSaving) return;
    _isSaving = true;
    RitmoHaptics.confirm();

    final now = DateTime.now();
    try {
      final db = await DatabaseHelper.instance.database;
      final completionId = 'comp_${widget.routine.id}_${now.millisecondsSinceEpoch}';

      await db.insert(
        'routine_completions',
        {
          'id': completionId,
          'routineId': widget.routine.id,
          'dateStr': widget.targetDate,
          'completedAt': now.millisecondsSinceEpoch,
          'result': 'FULL',
          'durationMinutes': widget.routine.targetDurationMinutes ?? 15,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final totalDoses = _dosesToday.length + 1;
      final isAllDosesCompleted = totalDoses >= _maxDoses;

      await db.insert(
        'routine_occurrences',
        {
          'routine_id': widget.routine.id,
          'date': widget.targetDate,
          'status': isAllDosesCompleted ? 'completed' : 'pending',
          'target_duration_minutes': widget.routine.targetDurationMinutes ?? 15,
          'actual_duration_minutes': widget.routine.targetDurationMinutes ?? 15,
          'completed_at': isAllDosesCompleted ? now.millisecondsSinceEpoch : null,
          'notes': 'دوز $totalDoses از $_maxDoses ثبت شد',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Invalidate and reschedule alarms
      DayAgendaService.instance.invalidateDate(widget.targetDate);
      await AlarmSchedulerService.scheduleNextAlarms();
      RitmoEvents.notifyRoutineChanged();
      RitmoEventBus().fire(RitmoEvent(
        type: 'RoutineUpdated',
        timestamp: now,
        payload: {
          'routineId': widget.routine.id,
          'date': widget.targetDate,
          'doses': totalDoses,
        },
      ));

      await _loadDoses();
      widget.onChanged?.call();
    } catch (e) {
      debugPrint('Error logging dose: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nextDose = _nextDose;
    final isMaxReached = _dosesToday.length >= _maxDoses;

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
                    'برنامه فاصله‌ای (هر ${toPersianDigits(_intervalHours.toString())} ساعت یک‌بار)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  // Doses Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            Text(
                              'نوبت‌های امروز:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                            Text(
                              '${toPersianDigits(_dosesToday.length.toString())} از ${toPersianDigits(_maxDoses.toString())} نوبت',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isMaxReached ? Colors.green : colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Timeline of logged doses
                        if (_dosesToday.isEmpty)
                          Text(
                            'هنوز نوبتی برای امروز ثبت نشده است.',
                            style: TextStyle(fontSize: 12, color: colors.textTertiary),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _dosesToday.asMap().entries.map((entry) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'نوبت ${toPersianDigits((entry.key + 1).toString())}: ساعت ${toPersianDigits(_formatTime(entry.value))}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Next Dose Alert Card
                  if (nextDose != null && !isMaxReached)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 20, color: colors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'نوبت بعدی: حدود ساعت ${toPersianDigits(_formatTime(nextDose))} (${toPersianDigits(_intervalHours.toString())} ساعت بعد)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Action Button
                  ElevatedButton(
                    onPressed: isMaxReached ? null : _logDoseNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isMaxReached ? 'تمام نوبت‌های امروز انجام شد 🎉' : 'ثبت نوبت اکنون ✓',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
