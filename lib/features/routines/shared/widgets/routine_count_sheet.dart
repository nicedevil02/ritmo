import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:sqflite/sqflite.dart';

/// Specialized Action & Tracking Sheet for Count-based Routines (RoutineType.countBased)
class RoutineCountSheet extends StatefulWidget {
  const RoutineCountSheet({
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
      builder: (context) => RoutineCountSheet(
        routine: routine,
        targetDate: targetDate,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<RoutineCountSheet> createState() => _RoutineCountSheetState();
}

class _RoutineCountSheetState extends State<RoutineCountSheet> {
  int _currentCount = 0;
  int _targetCount = 8;
  String _unit = 'بار';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _targetCount = widget.routine.maxDosesPerDay > 0 ? widget.routine.maxDosesPerDay : 8;
    _unit = (widget.routine.description != null && widget.routine.description!.trim().isNotEmpty)
        ? widget.routine.description!.trim()
        : 'بار';
    _loadTodayCount();
  }

  Future<void> _loadTodayCount() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final occurrences = await db.query(
        'routine_occurrences',
        where: 'routine_id = ? AND date = ?',
        whereArgs: [widget.routine.id, widget.targetDate],
        limit: 1,
      );

      if (occurrences.isNotEmpty) {
        final occ = occurrences.first;
        final count = (occ['target_duration_minutes'] as int?) ?? 0;
        final isDone = occ['status'] == 'completed';
        setState(() {
          _currentCount = isDone && count == 0 ? _targetCount : count;
          _isLoading = false;
        });
      } else {
        final completions = await db.query(
          'routine_completions',
          where: 'routineId = ? AND dateStr = ?',
          whereArgs: [widget.routine.id, widget.targetDate],
        );
        setState(() {
          _currentCount = completions.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading count for routine: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateCount(int newCount) async {
    if (newCount < 0) return;
    RitmoHaptics.selection();

    setState(() {
      _currentCount = newCount;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final isCompleted = _currentCount >= _targetCount;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert(
        'routine_occurrences',
        {
          'routine_id': widget.routine.id,
          'date': widget.targetDate,
          'status': isCompleted ? 'completed' : 'pending',
          'target_duration_minutes': _currentCount,
          'actual_duration_minutes': _currentCount,
          'completed_at': isCompleted ? now : null,
          'notes': 'تعداد: $_currentCount از $_targetCount $_unit',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      DayAgendaService.instance.invalidateDate(widget.targetDate);
      RitmoEvents.notifyRoutineChanged();
      RitmoEventBus().fire(RitmoEvent(
        type: 'RoutineUpdated',
        timestamp: DateTime.now(),
        payload: {
          'routineId': widget.routine.id,
          'date': widget.targetDate,
          'count': _currentCount,
        },
      ));
      widget.onChanged?.call();
    } catch (e) {
      debugPrint('Error saving count: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _targetCount > 0 ? (_currentCount / _targetCount).clamp(0.0, 1.5) : 0.0;
    final isReached = _currentCount >= _targetCount;

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
                crossAxisAlignment: CrossAxisAlignment.center,
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

                  // Header Title
                  Text(
                    widget.routine.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ردیابی پیشرفت عددی روزانه',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Circular Progress Display
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: min(progress, 1.0),
                          strokeWidth: 10,
                          backgroundColor: colors.border.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isReached ? Colors.green : colors.primary,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            toPersianDigits(_currentCount.toString()),
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: isReached ? Colors.green : colors.textPrimary,
                            ),
                          ),
                          Text(
                            'از ${toPersianDigits(_targetCount.toString())} $_unit',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  if (isReached)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'هدف امروز محقق شد! 🎉',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Quick Step Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCountButton(
                        label: '-۱',
                        onTap: () => _updateCount(_currentCount - 1),
                        colors: colors,
                        isSecondary: true,
                      ),
                      const SizedBox(width: 12),
                      _buildCountButton(
                        label: '+۱',
                        onTap: () => _updateCount(_currentCount + 1),
                        colors: colors,
                        isHighlight: true,
                      ),
                      const SizedBox(width: 12),
                      _buildCountButton(
                        label: '+۲',
                        onTap: () => _updateCount(_currentCount + 2),
                        colors: colors,
                      ),
                      const SizedBox(width: 12),
                      _buildCountButton(
                        label: '+۵',
                        onTap: () => _updateCount(_currentCount + 5),
                        colors: colors,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Close / Done button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        RitmoHaptics.confirm();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'ثبت و بستن',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCountButton({
    required String label,
    required VoidCallback onTap,
    required RitmoColors colors,
    bool isHighlight = false,
    bool isSecondary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isHighlight
              ? colors.primary
              : (isSecondary
                  ? colors.card.withValues(alpha: 0.5)
                  : colors.primary.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlight ? colors.primary : colors.border.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          toPersianDigits(label),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isHighlight ? Colors.white : (isSecondary ? colors.textSecondary : colors.primary),
          ),
        ),
      ),
    );
  }
}
