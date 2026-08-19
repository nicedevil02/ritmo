import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// شیت ثبت سریع انجام جلسه خارج از برنامه بدون ایجاد جلسهٔ زنده مصنوعی
class QuickCompleteSheet extends StatefulWidget {
  const QuickCompleteSheet({
    super.key,
    required this.occurrence,
    required this.onQuickComplete,
  });

  final MovementOccurrence occurrence;
  final Future<void> Function(
    int durationSec,
    double? metricValue,
    String? feeling,
    String? note,
  )
  onQuickComplete;

  static Future<bool?> show(
    BuildContext context, {
    required MovementOccurrence occurrence,
    required Future<void> Function(
      int durationSec,
      double? metricValue,
      String? feeling,
      String? note,
    )
    onQuickComplete,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: QuickCompleteSheet(
          occurrence: occurrence,
          onQuickComplete: (dur, met, feel, note) async {
            await onQuickComplete(dur, met, feel, note);
            if (ctx.mounted) {
              Navigator.of(ctx).pop(true);
            }
          },
        ),
      ),
    );
  }

  @override
  State<QuickCompleteSheet> createState() => _QuickCompleteSheetState();
}

class _QuickCompleteSheetState extends State<QuickCompleteSheet> {
  final _durationController = TextEditingController();
  final _metricController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedFeeling;
  bool _isSaving = false;

  final List<String> _feelings = ['عالی', 'خوب', 'معمولی', 'سخت', 'خسته'];

  @override
  void initState() {
    super.initState();
    final defaultMinutes =
        widget.occurrence.goalValue != null &&
            widget.occurrence.goalType == 'duration'
        ? widget.occurrence.goalValue!.toInt()
        : 30;
    _durationController.text = defaultMinutes.toString();
    if (widget.occurrence.goalValue != null &&
        widget.occurrence.goalType != 'duration') {
      _metricController.text = widget.occurrence.goalValue!.toString();
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _metricController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit({bool minimal = false}) async {
    setState(() => _isSaving = true);
    final minutes = int.tryParse(_durationController.text.trim()) ?? 30;
    final metricVal = double.tryParse(_metricController.text.trim());

    try {
      await widget.onQuickComplete(
        minutes * 60,
        metricVal,
        minimal ? null : _selectedFeeling,
        minimal
            ? null
            : (_noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim()),
      );
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
              MovementStrings.quickCompleteTitle,
              style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'ثبت سریع جلسهٔ «${widget.occurrence.displayName}»',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.lg),

            // فیلد مدت زمان انجام
            Text(
              '${MovementStrings.retroLogDuration} *',
              style: RitmoTextStyles.label(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.xs),
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              style: RitmoTextStyles.body(colors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: colors.surfaceSunken,
                suffixText: 'دقیقه',
                suffixStyle: RitmoTextStyles.label(colors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                  borderSide: BorderSide(color: sportsColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: RitmoSpacing.md),

            // حس بعد از تمرین
            Text(
              MovementStrings.retroLogFeeling,
              style: RitmoTextStyles.label(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.xs),
            Wrap(
              spacing: RitmoSpacing.sm,
              children: _feelings.map((feeling) {
                final isSelected = _selectedFeeling == feeling;
                return ChoiceChip(
                  label: Text(
                    feeling,
                    style: RitmoTextStyles.caption(
                      isSelected ? Colors.white : colors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: sportsColor,
                  onSelected: (sel) {
                    setState(() => _selectedFeeling = sel ? feeling : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: RitmoSpacing.lg),

            // دکمهٔ ثبت سریع
            SizedBox(
              width: double.infinity,
              height: MovementLayout.kFieldMinHeight,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _submit(minimal: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sportsColor,
                  foregroundColor: Colors.white,
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
                        MovementStrings.quickCompleteButton,
                        style: RitmoTextStyles.label(Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: RitmoSpacing.sm),

            // لینک تکمیل جزئیات بعداً
            Center(
              child: TextButton(
                onPressed: _isSaving ? null : () => _submit(minimal: true),
                child: Text(
                  MovementStrings.quickCompleteDetailsLater,
                  style: RitmoTextStyles.caption(
                    colors.textSecondary,
                  ).copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ),
            const SizedBox(height: RitmoSpacing.lg),
          ],
        ),
      ),
    );
  }
}
