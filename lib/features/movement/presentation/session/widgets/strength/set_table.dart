import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_set_log.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_exercise.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/set_row.dart';

/// جدول ثبت ست‌های تمرینی برای حرکت جاری
class SetTable extends StatelessWidget {
  const SetTable({
    super.key,
    required this.exercise,
    required this.setLogs,
    required this.hintLogs,
    required this.onSetWeightChanged,
    required this.onSetRepsChanged,
    required this.onToggleCompleted,
    required this.onAddSet,
  });

  final MovementStrengthExercise exercise;
  final List<MovementSetLog> setLogs;
  final List<MovementSetLog> hintLogs;
  final void Function(int setIndex, double? weight) onSetWeightChanged;
  final void Function(int setIndex, int? reps) onSetRepsChanged;
  final void Function(int setIndex) onToggleCompleted;
  final VoidCallback onAddSet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final targetSetsCount = exercise.sets > setLogs.length
        ? exercise.sets
        : setLogs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // سربرگ جدول
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.sm,
            vertical: RitmoSpacing.xs,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  'ست',
                  textAlign: TextAlign.center,
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ),
              const SizedBox(width: RitmoSpacing.xs),
              Expanded(
                flex: 2,
                child: Text(
                  'هدف/قبل',
                  textAlign: TextAlign.center,
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ),
              const SizedBox(width: RitmoSpacing.xs),
              Expanded(
                flex: 2,
                child: Text(
                  'وزن (kg)',
                  textAlign: TextAlign.center,
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ),
              const SizedBox(width: RitmoSpacing.xs),
              Expanded(
                flex: 2,
                child: Text(
                  'تکرار',
                  textAlign: TextAlign.center,
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ),
              const SizedBox(width: RitmoSpacing.xs),
              SizedBox(
                width: 48,
                child: Text(
                  'ثبت',
                  textAlign: TextAlign.center,
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // ردیف‌های ست‌ها
        ...List.generate(targetSetsCount, (index) {
          final setNum = index + 1;
          final log = setLogs.firstWhere(
            (l) => l.setIndex == setNum,
            orElse: () => MovementSetLog(
              id: '',
              exerciseId: exercise.id,
              setIndex: setNum,
              at: DateTime.now(),
            ),
          );
          final hint = hintLogs.where((h) => h.setIndex == setNum).isNotEmpty
              ? hintLogs.firstWhere((h) => h.setIndex == setNum)
              : null;

          return SetRow(
            key: ValueKey('set_${exercise.id}_$setNum'),
            setIndex: setNum,
            targetReps: exercise.repsDisplay,
            log: log.id.isNotEmpty ? log : null,
            hintLog: hint,
            onWeightChanged: (w) => onSetWeightChanged(setNum, w),
            onRepsChanged: (r) => onSetRepsChanged(setNum, r),
            onToggleCompleted: () => onToggleCompleted(setNum),
          );
        }),

        const SizedBox(height: RitmoSpacing.xs),

        // دکمه افزودن ست
        TextButton.icon(
          onPressed: onAddSet,
          icon: Icon(Icons.add_rounded, size: 18, color: sportsColor),
          label: Text(
            MovementStrings.strengthAddSet,
            style: RitmoTextStyles.label(sportsColor),
          ),
        ),
      ],
    );
  }
}
