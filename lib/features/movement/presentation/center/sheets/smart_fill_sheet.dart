import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/reason_chip.dart';

class SmartFillSuggestionItem {
  SmartFillSuggestionItem({
    required this.weekday,
    required this.weekdayName,
    required this.activityKind,
    required this.durationMin,
    required this.timeOfDay,
    required this.reason,
    this.isSelected = true,
  });

  final int weekday;
  final String weekdayName;
  final MovementActivityKind activityKind;
  final int durationMin;
  final String timeOfDay;
  final String reason;
  bool isSelected;
}

/// شیت پیشنهاد هوشمند برنامهٔ هفتگی در دو مرحله (تنظیم ورودی‌ها -> پیش‌نمایش و اعمال انتخابی)
class SmartFillSheet extends StatefulWidget {
  const SmartFillSheet({
    super.key,
    required this.availableKinds,
    required this.onApplySuggestions,
  });

  final List<MovementActivityKind> availableKinds;
  final Future<void> Function(List<SmartFillSuggestionItem> selectedItems)
  onApplySuggestions;

  static Future<bool?> show(
    BuildContext context, {
    required List<MovementActivityKind> availableKinds,
    required Future<void> Function(List<SmartFillSuggestionItem> selectedItems)
    onApplySuggestions,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmartFillSheet(
        availableKinds: availableKinds,
        onApplySuggestions: (items) async {
          await onApplySuggestions(items);
          if (ctx.mounted) {
            Navigator.of(ctx).pop(true);
          }
        },
      ),
    );
  }

  @override
  State<SmartFillSheet> createState() => _SmartFillSheetState();
}

class _SmartFillSheetState extends State<SmartFillSheet> {
  int _currentStep = 1; // 1: Inputs, 2: Preview
  int _targetDays = 3;
  int _timePerDayMinutes = 30;
  final Set<int> _forbiddenDays = {};
  bool _preferHomeWorkout = false;

  List<SmartFillSuggestionItem> _suggestions = [];
  bool _isSaving = false;

  static const _weekdayFullNames = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  void _generateSuggestions() {
    final available = widget.availableKinds.where((k) {
      if (_preferHomeWorkout &&
          (k.family == 'hiking' || k.family == 'swimming')) {
        return false;
      }
      return true;
    }).toList();

    if (available.isEmpty || _targetDays > (7 - _forbiddenDays.length)) {
      setState(() {
        _suggestions = [];
        _currentStep = 2;
      });
      return;
    }

    final items = <SmartFillSuggestionItem>[];
    final candidateDays = [
      0,
      2,
      4,
      1,
      3,
      5,
      6,
    ].where((d) => !_forbiddenDays.contains(d)).toList();

    for (int i = 0; i < _targetDays && i < candidateDays.length; i++) {
      final day = candidateDays[i];
      final kind = available[i % available.length];
      final reason = i == 0
          ? MovementStrings.reasonInterest
          : (i % 2 == 0
                ? MovementStrings.reasonRecoveryGap
                : MovementStrings.reasonAvailableTime);

      items.add(
        SmartFillSuggestionItem(
          weekday: day,
          weekdayName: _weekdayFullNames[day],
          activityKind: kind,
          durationMin: _timePerDayMinutes,
          timeOfDay: '18:30',
          reason: reason,
          isSelected: true,
        ),
      );
    }

    setState(() {
      _suggestions = items;
      _currentStep = 2;
    });
  }

  Future<void> _submit() async {
    final selected = _suggestions.where((s) => s.isSelected).toList();
    if (selected.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await widget.onApplySuggestions(selected);
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
              MovementStrings.smartFillTitle,
              style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              _currentStep == 1
                  ? 'بر اساس زمان در دسترس و علایقت، یک هفتهٔ متوازن به تو پیشنهاد می‌شود.'
                  : 'جلسات زیر به برنامهٔ هفته اضافه می‌شوند. می‌توانی موارد دلخواه را انتخاب کنی.',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.lg),

            if (_currentStep == 1) ...[
              // گام ۱: ورودی‌ها
              Text(
                'تعداد روزهای تمرین در هفته:',
                style: RitmoTextStyles.body(
                  colors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: RitmoSpacing.sm),
              Wrap(
                spacing: RitmoSpacing.sm,
                children: [2, 3, 4, 5].map((days) {
                  final isSelected = _targetDays == days;
                  return ChoiceChip(
                    label: Text('${toPersianDigits(days)} روز'),
                    selected: isSelected,
                    selectedColor: sportsColor,
                    onSelected: (sel) {
                      if (sel) setState(() => _targetDays = days);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: RitmoSpacing.lg),

              Text(
                'مدت زمان در دسترس برای هر جلسه:',
                style: RitmoTextStyles.body(
                  colors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: RitmoSpacing.sm),
              Wrap(
                spacing: RitmoSpacing.sm,
                children: [15, 30, 45, 60].map((mins) {
                  final isSelected = _timePerDayMinutes == mins;
                  return ChoiceChip(
                    label: Text('${toPersianDigits(mins)} دقیقه'),
                    selected: isSelected,
                    selectedColor: sportsColor,
                    onSelected: (sel) {
                      if (sel) setState(() => _timePerDayMinutes = mins);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: RitmoSpacing.lg),

              Text(
                'روزهای ممنوع (عدم تمایل به ورزش):',
                style: RitmoTextStyles.body(
                  colors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: RitmoSpacing.sm),
              Wrap(
                spacing: RitmoSpacing.xs,
                children: List.generate(7, (i) {
                  final isForbidden = _forbiddenDays.contains(i);
                  return FilterChip(
                    label: Text(_weekdayFullNames[i]),
                    selected: isForbidden,
                    selectedColor: colors.error.withValues(alpha: 0.2),
                    checkmarkColor: colors.error,
                    onSelected: (sel) {
                      setState(() {
                        if (sel) {
                          _forbiddenDays.add(i);
                        } else {
                          _forbiddenDays.remove(i);
                        }
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: RitmoSpacing.md),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ترجیح فعالیت و تمرین در خانه',
                    style: RitmoTextStyles.body(colors.textPrimary),
                  ),
                  Switch(
                    value: _preferHomeWorkout,
                    activeThumbColor: sportsColor,
                    onChanged: (v) => setState(() => _preferHomeWorkout = v),
                  ),
                ],
              ),
              const SizedBox(height: RitmoSpacing.xl),

              SizedBox(
                width: double.infinity,
                height: MovementLayout.kFieldMinHeight,
                child: ElevatedButton(
                  onPressed: _generateSuggestions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sportsColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  child: Text(
                    'تولید پیشنهاد هوشمند',
                    style: RitmoTextStyles.label(Colors.white),
                  ),
                ),
              ),
            ] else ...[
              // گام ۲: پیش‌نمایش و اعمال
              if (_suggestions.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(RitmoSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colors.textSecondary,
                        size: 36,
                      ),
                      const SizedBox(height: RitmoSpacing.sm),
                      Text(
                        MovementStrings.smartFillNoSuggestion,
                        style: RitmoTextStyles.body(
                          colors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: RitmoSpacing.lg),
                      ElevatedButton(
                        onPressed: () => setState(() => _currentStep = 1),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sportsColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          MovementStrings.smartFillFixConstraints,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ..._suggestions.map((sug) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: RitmoSpacing.sm),
                    padding: const EdgeInsets.all(RitmoSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(RitmoRadius.card),
                      border: Border.all(
                        color: sug.isSelected ? sportsColor : colors.border,
                        width: sug.isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: sug.isSelected,
                          activeColor: sportsColor,
                          onChanged: (val) {
                            setState(() => sug.isSelected = val ?? false);
                          },
                        ),
                        const SizedBox(width: RitmoSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${sug.weekdayName} • ${sug.activityKind.nameFa}',
                                style: RitmoTextStyles.cardTitle(
                                  colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ساعت ${toPersianDigits(sug.timeOfDay)} • ${toPersianDigits(sug.durationMin)} دقیقه',
                                style: RitmoTextStyles.caption(
                                  colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ReasonChip(reason: sug.reason),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: RitmoSpacing.lg),

                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep = 1),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(
                            48,
                            MovementLayout.kFieldMinHeight,
                          ),
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              RitmoRadius.field,
                            ),
                          ),
                        ),
                        child: Text(
                          'تغییر ورودی‌ها',
                          style: RitmoTextStyles.label(colors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: RitmoSpacing.md),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed:
                            _suggestions.any((s) => s.isSelected) && !_isSaving
                            ? _submit
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sportsColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(
                            48,
                            MovementLayout.kFieldMinHeight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              RitmoRadius.field,
                            ),
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
                                MovementStrings.smartFillApplySelected,
                                style: RitmoTextStyles.label(Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            const SizedBox(height: RitmoSpacing.lg),
          ],
        ),
      ),
    );
  }
}
