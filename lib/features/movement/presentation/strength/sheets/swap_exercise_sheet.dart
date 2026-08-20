import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_exercise.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// نتیجهٔ انتخاب در شیت جایگزینی حرکت
class SwapExerciseResult {
  const SwapExerciseResult({
    required this.newExerciseNameFa,
    required this.newMuscleGroup,
    required this.scope,
    this.shouldSkip = false,
  });

  final String newExerciseNameFa;
  final String newMuscleGroup;
  final MovementChangeScope scope;
  final bool shouldSkip;
}

/// شیت دو مرحله‌ای جایگزینی حرکت (SwapExerciseSheet)
class SwapExerciseSheet extends StatefulWidget {
  const SwapExerciseSheet({super.key, required this.currentExercise});

  final MovementStrengthExercise currentExercise;

  static Future<SwapExerciseResult?> show(
    BuildContext context, {
    required MovementStrengthExercise currentExercise,
  }) {
    return showModalBottomSheet<SwapExerciseResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SwapExerciseSheet(currentExercise: currentExercise),
    );
  }

  @override
  State<SwapExerciseSheet> createState() => _SwapExerciseSheetState();
}

class _SwapExerciseSheetState extends State<SwapExerciseSheet> {
  int _step = 1; // 1: Reason, 2: Select alternative & scope
  String _selectedReason = 'equipment';
  String? _selectedAlternative;
  MovementChangeScope _scope = MovementChangeScope.onlyThis;

  static const List<Map<String, String>> _reasons = [
    {'id': 'pain', 'label': 'احساس درد یا ناراحتی در مفصل'},
    {'id': 'equipment', 'label': 'عدم دسترسی به وسیلهٔ مناسب'},
    {'id': 'difficulty', 'label': 'حرکت خیلی سنگین یا خیلی سبک است'},
    {'id': 'space', 'label': 'کمبود فضای کافی در محیط'},
    {'id': 'preference', 'label': 'علاقه به تنوع حرکتی'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.currentExercise.alternatives.isNotEmpty) {
      _selectedAlternative = widget.currentExercise.alternatives.first;
    }
  }

  void _handleConfirm() {
    if (_selectedAlternative == null) return;
    Navigator.of(context).pop(
      SwapExerciseResult(
        newExerciseNameFa: _selectedAlternative!,
        newMuscleGroup: widget.currentExercise.muscleGroup,
        scope: _scope,
        shouldSkip: false,
      ),
    );
  }

  void _handleSkipExercise() {
    Navigator.of(context).pop(
      SwapExerciseResult(
        newExerciseNameFa: widget.currentExercise.nameFa,
        newMuscleGroup: widget.currentExercise.muscleGroup,
        scope: MovementChangeScope.onlyThis,
        shouldSkip: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(RitmoRadius.sheet),
      ),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + RitmoSpacing.lg,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: RitmoSpacing.md),
                Center(
                  child: Container(
                    width: MovementLayout.kSheetHandleSize.width,
                    height: MovementLayout.kSheetHandleSize.height,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: RitmoSpacing.lg),

                Text(
                  'جایگزینی حرکت «${widget.currentExercise.nameFa}»',
                  style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
                ),
                const SizedBox(height: RitmoSpacing.xs),
                Text(
                  'ست‌های ثبت‌شدهٔ شما حفظ خواهند شد.',
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
                const SizedBox(height: RitmoSpacing.lg),

                if (_step == 1) ...[
                  // مرحلهٔ ۱: دلیل تعویض
                  Text(
                    'دلیل جایگزینی را مشخص کنید:',
                    style: RitmoTextStyles.label(colors.textPrimary),
                  ),
                  const SizedBox(height: RitmoSpacing.sm),
                  ..._reasons.map((r) {
                    final isSel = _selectedReason == r['id'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: RitmoSpacing.xs),
                      child: InkWell(
                        onTap: () => setState(() => _selectedReason = r['id']!),
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        child: Container(
                          padding: const EdgeInsets.all(RitmoSpacing.md),
                          decoration: BoxDecoration(
                            color: isSel
                                ? sportsColor.withValues(alpha: 0.1)
                                : colors.surface,
                            borderRadius: BorderRadius.circular(
                              RitmoRadius.card,
                            ),
                            border: Border.all(
                              color: isSel ? sportsColor : colors.border,
                              width: isSel ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel
                                        ? sportsColor
                                        : colors.textTertiary,
                                    width: isSel ? 6 : 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: RitmoSpacing.md),
                              Expanded(
                                child: Text(
                                  r['label']!,
                                  style: RitmoTextStyles.body(
                                    isSel ? sportsColor : colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: RitmoSpacing.md),
                  ElevatedButton(
                    onPressed: () => setState(() => _step = 2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sportsColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(
                        double.infinity,
                        MovementLayout.kPrimaryButtonHeight,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                      ),
                    ),
                    child: const Text('مشاهدهٔ حرکات جایگزین'),
                  ),
                ] else ...[
                  // مرحلهٔ ۲: انتخاب حرکت جایگزین و دامنهٔ تغییر
                  Text(
                    'انتخاب حرکت جایگزین هم‌عضله:',
                    style: RitmoTextStyles.label(colors.textPrimary),
                  ),
                  const SizedBox(height: RitmoSpacing.sm),
                  ...widget.currentExercise.alternatives.map((alt) {
                    final isSel = _selectedAlternative == alt;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: RitmoSpacing.xs),
                      child: InkWell(
                        onTap: () => setState(() => _selectedAlternative = alt),
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        child: Container(
                          padding: const EdgeInsets.all(RitmoSpacing.md),
                          decoration: BoxDecoration(
                            color: isSel
                                ? sportsColor.withValues(alpha: 0.1)
                                : colors.surface,
                            borderRadius: BorderRadius.circular(
                              RitmoRadius.card,
                            ),
                            border: Border.all(
                              color: isSel ? sportsColor : colors.border,
                              width: isSel ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel
                                        ? sportsColor
                                        : colors.textTertiary,
                                    width: isSel ? 6 : 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: RitmoSpacing.md),
                              Expanded(
                                child: Text(
                                  alt,
                                  style: RitmoTextStyles.label(
                                    isSel ? sportsColor : colors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: RitmoSpacing.md),

                  // دامنهٔ تغییر
                  Text(
                    'دامنهٔ اعمال تغییر:',
                    style: RitmoTextStyles.label(colors.textPrimary),
                  ),
                  const SizedBox(height: RitmoSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Text(MovementStrings.strengthSwapOnlyToday),
                          ),
                          selected: _scope == MovementChangeScope.onlyThis,
                          selectedColor: sportsColor.withValues(alpha: 0.2),
                          onSelected: (_) => setState(
                            () => _scope = MovementChangeScope.onlyThis,
                          ),
                        ),
                      ),
                      const SizedBox(width: RitmoSpacing.sm),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Text(
                              MovementStrings.strengthSwapWholeProgram,
                            ),
                          ),
                          selected: _scope == MovementChangeScope.wholePlan,
                          selectedColor: sportsColor.withValues(alpha: 0.2),
                          onSelected: (_) => setState(
                            () => _scope = MovementChangeScope.wholePlan,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RitmoSpacing.lg),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _handleSkipExercise,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                              48,
                              MovementLayout.kPrimaryButtonHeight,
                            ),
                            side: BorderSide(color: colors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                RitmoRadius.field,
                              ),
                            ),
                          ),
                          child: const Text('رد کردن این حرکت'),
                        ),
                      ),
                      const SizedBox(width: RitmoSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedAlternative != null
                              ? _handleConfirm
                              : null,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(
                              48,
                              MovementLayout.kPrimaryButtonHeight,
                            ),
                            backgroundColor: sportsColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                RitmoRadius.field,
                              ),
                            ),
                          ),
                          child: const Text('تأیید جایگزینی'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: RitmoSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
