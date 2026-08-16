import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_set_log.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';

/// ردیف نمایش و ثبت یک ست تمرینی با ارتفاع استاندارد kSetRowHeight
class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.setIndex,
    required this.targetReps,
    required this.log,
    this.hintLog,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onToggleCompleted,
    this.onDelete,
  });

  final int setIndex;
  final String targetReps;
  final MovementSetLog? log;
  final MovementSetLog? hintLog;
  final ValueChanged<double?> onWeightChanged;
  final ValueChanged<int?> onRepsChanged;
  final VoidCallback onToggleCompleted;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final isCompleted = log?.completed ?? false;
    final currentWeight = log?.weightKg;
    final currentReps = log?.reps;

    // متن Hint جلسه قبل
    String hintText = targetReps;
    if (hintLog != null && hintLog!.completed) {
      final hintW = hintLog!.weightKg != null ? '${hintLog!.weightKg} ک' : '';
      final hintR = hintLog!.reps != null ? '${hintLog!.reps} ت' : '';
      hintText = '$hintW $hintR'.trim();
    }

    final semanticsLabel = 'ست ${toPersianDigits(setIndex)}، '
        '${currentWeight != null ? '${toPersianDigits(currentWeight)} کیلوگرم' : 'بدون وزن'}، '
        '${currentReps != null ? '${toPersianDigits(currentReps)} تکرار' : 'هدف $targetReps'}، '
        '${isCompleted ? 'انجام شده' : 'در انتظار'}';

    return Semantics(
      label: semanticsLabel,
      container: true,
      child: Container(
        height: MovementLayout.kSetRowHeight,
        margin: const EdgeInsets.only(bottom: RitmoSpacing.xs),
        padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.sm),
        decoration: BoxDecoration(
          color: isCompleted ? sportsColor.withValues(alpha: 0.08) : colors.surface,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(
            color: isCompleted ? sportsColor.withValues(alpha: 0.3) : colors.border,
          ),
        ),
        child: Row(
          children: [
            // شماره ست
            SizedBox(
              width: 32,
              child: Text(
                toPersianDigits(setIndex),
                textAlign: TextAlign.center,
                style: RitmoTextStyles.label(colors.textPrimary).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: RitmoSpacing.xs),

            // ستون قبلی (فقط Hint)
            Expanded(
              flex: 2,
              child: Text(
                toPersianDigits(hintText),
                textAlign: TextAlign.center,
                style: RitmoTextStyles.caption(colors.textTertiary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: RitmoSpacing.xs),

            // ستون وزن (کیلوگرم)
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () async {
                  final entered = await _showInputDialog(
                    context,
                    title: 'وزنه (کیلوگرم)',
                    initialValue: currentWeight?.toString() ?? '',
                    isDecimal: true,
                  );
                  if (entered != null) {
                    onWeightChanged(double.tryParse(entered));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                  child: Text(
                    currentWeight != null ? toPersianDigits(currentWeight) : '—',
                    textAlign: TextAlign.center,
                    style: RitmoTextStyles.body(colors.textPrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: RitmoSpacing.xs),

            // ستون تکرار
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () async {
                  final entered = await _showInputDialog(
                    context,
                    title: 'تعداد تکرار',
                    initialValue: currentReps?.toString() ?? targetReps.split('-').first.trim(),
                    isDecimal: false,
                  );
                  if (entered != null) {
                    onRepsChanged(int.tryParse(entered));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                  child: Text(
                    currentReps != null ? toPersianDigits(currentReps) : toPersianDigits(targetReps),
                    textAlign: TextAlign.center,
                    style: RitmoTextStyles.body(colors.textPrimary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: RitmoSpacing.xs),

            // دکمه تیک / ثبت انجام ست
            IconButton(
              icon: Icon(
                isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isCompleted ? sportsColor : colors.textTertiary,
                size: 26,
              ),
              onPressed: onToggleCompleted,
              tooltip: isCompleted ? 'ست انجام شد' : 'ثبت انجام ست',
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showInputDialog(
    BuildContext context, {
    required String title,
    required String initialValue,
    required bool isDecimal,
  }) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title, style: RitmoTextStyles.cardTitle(dialogCtx.colors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(controller.text.trim()),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
  }
}
