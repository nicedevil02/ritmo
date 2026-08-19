import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// گروه فیلدهای هدف برای برنامه‌ریزی فعالیت ورزشی متناسب با خانواده ورزشی
class GoalFieldGroup extends StatefulWidget {
  const GoalFieldGroup({
    super.key,
    required this.family,
    required this.primaryMetric,
    this.initialGoalType = 'duration',
    this.initialGoalValue = 30.0,
    this.initialGoalUnit = 'دقیقه',
    required this.onGoalChanged,
  });

  final String family;
  final String primaryMetric;
  final String initialGoalType;
  final double initialGoalValue;
  final String initialGoalUnit;
  final void Function(String type, double value, String unit) onGoalChanged;

  @override
  State<GoalFieldGroup> createState() => _GoalFieldGroupState();
}

class _GoalFieldGroupState extends State<GoalFieldGroup> {
  late String _goalType;
  late final TextEditingController _valueController;
  late String _goalUnit;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _goalType = widget.initialGoalType;
    _valueController = TextEditingController(
      text: widget.initialGoalValue.toStringAsFixed(
        widget.initialGoalValue.truncateToDouble() == widget.initialGoalValue
            ? 0
            : 1,
      ),
    );
    _goalUnit = widget.initialGoalUnit;
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  double get _suggestedValue {
    switch (widget.family) {
      case 'running':
      case 'cycling':
        return _goalType == 'distance' ? 5.0 : 30.0;
      case 'swimming':
        return _goalType == 'distance' ? 1.0 : 45.0;
      case 'strength':
        return 45.0;
      default:
        return 30.0;
    }
  }

  void _onValueChanged(String str) {
    final val = double.tryParse(str.trim());
    if (val == null || val <= 0) {
      setState(() {
        _inlineError = 'مقدار هدف باید عددی بزرگ‌تر از صفر باشد';
      });
      return;
    }
    setState(() => _inlineError = null);
    widget.onGoalChanged(_goalType, val, _goalUnit);
  }

  void _applySuggestion() {
    final val = _suggestedValue;
    _valueController.text = val.toStringAsFixed(
      val.truncateToDouble() == val ? 0 : 1,
    );
    _onValueChanged(_valueController.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // انتخاب نوع هدف
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                MovementStrings.plannerStepGoal,
                style: RitmoTextStyles.cardTitle(colors.textPrimary),
              ),
              // دکمهٔ برچسب پیشنهادی
              InkWell(
                onTap: _applySuggestion,
                borderRadius: BorderRadius.circular(RitmoRadius.badge),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sportsColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(RitmoRadius.badge),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: sportsColor,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${MovementStrings.goalSuggestedBadge}: ${toPersianDigits(_suggestedValue.toInt())} $_goalUnit',
                        style: RitmoTextStyles.badge(sportsColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),

          // انتخاب واحد هدف
          Wrap(
            spacing: RitmoSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text(MovementStrings.goalTypeDuration),
                selected: _goalType == 'duration',
                selectedColor: sportsColor,
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _goalType = 'duration';
                      _goalUnit = 'دقیقه';
                    });
                    _onValueChanged(_valueController.text);
                  }
                },
              ),
              if (widget.family == 'running' ||
                  widget.family == 'cycling' ||
                  widget.family == 'swimming')
                ChoiceChip(
                  label: const Text(MovementStrings.goalTypeDistance),
                  selected: _goalType == 'distance',
                  selectedColor: sportsColor,
                  onSelected: (sel) {
                    if (sel) {
                      setState(() {
                        _goalType = 'distance';
                        _goalUnit = 'کیلومتر';
                      });
                      _onValueChanged(_valueController.text);
                    }
                  },
                ),
              ChoiceChip(
                label: const Text(MovementStrings.goalTypeCalories),
                selected: _goalType == 'calories',
                selectedColor: sportsColor,
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _goalType = 'calories';
                      _goalUnit = 'کالری';
                    });
                    _onValueChanged(_valueController.text);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),

          // فیلد مقدار عددی هدف
          TextFormField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: RitmoTextStyles.body(colors.textPrimary),
            onChanged: _onValueChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.surfaceSunken,
              suffixText: _goalUnit,
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

          // خطای درون‌فیلدی
          if (_inlineError != null) ...[
            const SizedBox(height: RitmoSpacing.xs),
            Text(_inlineError!, style: RitmoTextStyles.caption(colors.error)),
          ],
        ],
      ),
    );
  }
}
