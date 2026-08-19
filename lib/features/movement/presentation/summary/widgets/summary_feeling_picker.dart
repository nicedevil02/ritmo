import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// انتخابگر حس بعد از تمرین با ۵ برچسب متنی و یادداشت اختیاری تا ۲۰۰ کاراکتر
class SummaryFeelingPicker extends StatelessWidget {
  const SummaryFeelingPicker({
    super.key,
    required this.selectedFeeling,
    required this.onFeelingChanged,
    required this.noteController,
    this.onNoteChanged,
  });

  final String? selectedFeeling;
  final ValueChanged<String?> onFeelingChanged;
  final TextEditingController noteController;
  final ValueChanged<String>? onNoteChanged;

  static const List<String> _feelings = [
    'عالی',
    'خوب',
    'معمولی',
    'سخت',
    'خسته',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MovementStrings.retroLogFeeling,
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.md),

          // چیپ‌های ۵ گانه حس با برچسب‌های متنی
          Wrap(
            spacing: RitmoSpacing.sm,
            runSpacing: RitmoSpacing.xs,
            children: _feelings.map((feeling) {
              final isSel = selectedFeeling == feeling;
              return ChoiceChip(
                label: Text(feeling),
                selected: isSel,
                selectedColor: sportsColor.withValues(alpha: 0.2),
                labelStyle: RitmoTextStyles.label(
                  isSel ? sportsColor : colors.textSecondary,
                ),
                onSelected: (sel) {
                  onFeelingChanged(sel ? feeling : null);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: RitmoSpacing.md),

          // یادداشت اختیاری
          TextField(
            controller: noteController,
            maxLength: 200,
            maxLines: 2,
            style: RitmoTextStyles.body(colors.textPrimary),
            onChanged: onNoteChanged,
            decoration: InputDecoration(
              hintText: 'یادداشت کوتاه دربارهٔ این جلسه (اختیاری)...',
              hintStyle: RitmoTextStyles.body(colors.textTertiary),
              filled: true,
              fillColor: colors.surfaceSunken,
              counterStyle: RitmoTextStyles.caption(colors.textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RitmoRadius.field),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(RitmoRadius.field),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
