import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/reason_chip.dart';

class WeekReshuffleChangeItem {
  WeekReshuffleChangeItem({
    required this.occurrence,
    required this.originalDateIso,
    required this.proposedDateIso,
    required this.originalTime,
    required this.proposedTime,
    required this.reason,
    this.isSelected = true,
  });

  final MovementOccurrence occurrence;
  final String originalDateIso;
  final String proposedDateIso;
  final String originalTime;
  final String proposedTime;
  final String reason;
  bool isSelected;

  bool get isLocked => occurrence.isCompleted;
}

/// شیت بازآرایی برنامهٔ هفتگی همراه با نمایش فهرست تغییرات (DiffList)
class WeekReshuffleSheet extends StatefulWidget {
  const WeekReshuffleSheet({
    super.key,
    required this.changes,
    required this.onApplyChanges,
  });

  final List<WeekReshuffleChangeItem> changes;
  final Future<void> Function(List<WeekReshuffleChangeItem> selectedChanges)
  onApplyChanges;

  static Future<bool?> show(
    BuildContext context, {
    required List<WeekReshuffleChangeItem> changes,
    required Future<void> Function(
      List<WeekReshuffleChangeItem> selectedChanges,
    )
    onApplyChanges,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WeekReshuffleSheet(
        changes: changes,
        onApplyChanges: (items) async {
          await onApplyChanges(items);
          if (ctx.mounted) {
            Navigator.of(ctx).pop(true);
          }
        },
      ),
    );
  }

  @override
  State<WeekReshuffleSheet> createState() => _WeekReshuffleSheetState();
}

class _WeekReshuffleSheetState extends State<WeekReshuffleSheet> {
  bool _isSaving = false;

  Future<void> _submitAll() async {
    for (final c in widget.changes) {
      if (!c.isLocked) c.isSelected = true;
    }
    await _submit();
  }

  Future<void> _submit() async {
    final selected = widget.changes
        .where((c) => c.isSelected && !c.isLocked)
        .toList();
    if (selected.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await widget.onApplyChanges(selected);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RitmoRadius.sheet),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // دستگیره شیت
            Center(
              child: Container(
                width: MovementLayout.kSheetHandleSize.width,
                height: MovementLayout.kSheetHandleSize.height,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: RitmoSpacing.lg),

            Text(
              MovementStrings.weekReshuffleTitle,
              style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'بهینه‌سازی توزیع جلسات بر اساس فاصلهٔ ریکاوری و زمان‌های آزاد',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.lg),

            // فهرست تغییرات (DiffList)
            ...widget.changes.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: RitmoSpacing.sm),
                padding: const EdgeInsets.all(RitmoSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(
                    color: item.isLocked
                        ? colors.border
                        : (item.isSelected ? sportsColor : colors.border),
                    width: item.isSelected && !item.isLocked ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!item.isLocked)
                      Checkbox(
                        value: item.isSelected,
                        activeColor: sportsColor,
                        onChanged: (val) {
                          setState(() => item.isSelected = val ?? false);
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: colors.textSecondary,
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: RitmoSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.occurrence.displayName,
                                style: RitmoTextStyles.cardTitle(
                                  colors.textPrimary,
                                ),
                              ),
                              if (item.isLocked) ...[
                                const Spacer(),
                                Text(
                                  MovementStrings.diffLocked,
                                  style: RitmoTextStyles.caption(
                                    colors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '${MovementStrings.diffBefore}: ${toPersianDigits(item.originalDateIso)} (${toPersianDigits(item.originalTime)})',
                                style: RitmoTextStyles.caption(colors.error)
                                    .copyWith(
                                      decoration: TextDecoration.lineThrough,
                                    ),
                              ),
                              const SizedBox(width: RitmoSpacing.sm),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: sportsColor,
                                size: 14,
                              ),
                              const SizedBox(width: RitmoSpacing.sm),
                              Text(
                                '${MovementStrings.diffAfter}: ${toPersianDigits(item.proposedDateIso)} (${toPersianDigits(item.proposedTime)})',
                                style: RitmoTextStyles.caption(
                                  sportsColor,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ReasonChip(reason: item.reason),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: RitmoSpacing.lg),

            // دکمه‌های اقدام
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(
                        48,
                        MovementLayout.kFieldMinHeight,
                      ),
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                      ),
                    ),
                    child: Text(
                      MovementStrings.commonCancel,
                      style: RitmoTextStyles.label(colors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: RitmoSpacing.md),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submitAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sportsColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(
                        48,
                        MovementLayout.kFieldMinHeight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            MovementStrings.weekReshuffleApplyAll,
                            style: RitmoTextStyles.label(Colors.white),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.lg),
          ],
        ),
      ),
    );
  }
}
