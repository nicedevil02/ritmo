// lib/features/supplementary_sports/movement/presentation/planner/week_smart_fill_sheet.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_plan_writer.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_suggester.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_plan_item.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/movement_plan_sheet.dart';

const String _fontFa = 'Vazirmatn';

Future<void> showWeekSmartFillSheet(
  BuildContext context, {
  required List<MovementWeekSuggestion> suggestions,
  VoidCallback? onApplied,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => WeekSmartFillSheet(
      suggestions: suggestions,
      onApplied: onApplied,
    ),
  );
}

class WeekSmartFillSheet extends StatefulWidget {
  const WeekSmartFillSheet({
    super.key,
    required this.suggestions,
    this.onApplied,
  });

  final List<MovementWeekSuggestion> suggestions;
  final VoidCallback? onApplied;

  @override
  State<WeekSmartFillSheet> createState() => _WeekSmartFillSheetState();
}

class _WeekSmartFillSheetState extends State<WeekSmartFillSheet> {
  final Set<int> _selectedIndices = <int>{};
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.suggestions.length; i++) {
      _selectedIndices.add(i);
    }
  }

  Future<void> _applySelected() async {
    if (_selectedIndices.isEmpty || _isApplying) return;

    setState(() => _isApplying = true);

    try {
      final selectedSuggestions =
          _selectedIndices.map((idx) => widget.suggestions[idx]).toList();

      for (final s in selectedSuggestions) {
        final dartWeekday = sat0ToDartWeekday(s.weekdaySat0);
        await MovementPlanWriter.savePlan(
          kind: s.kind,
          muscleFocus: s.kind.family == MovementFamily.strength ? 'FULL_BODY' : null,
          dayTimesDartWeekday: {dartWeekday: s.suggestedTime},
          targetDurationMinutes: s.suggestedMinutes,
          targetValue: s.kind.defaultTargetValue(durationMinutes: s.suggestedMinutes),
          reminderMinutes: s.reminderMinutes,
        );
      }

      RitmoEventBus().fire(
        RitmoEvent(
          type: 'smart_fill_accepted',
          timestamp: DateTime.now(),
          payload: {
            'count': selectedSuggestions.length,
            'kinds': selectedSuggestions.map((s) => s.kind.code).toList(),
          },
        ),
      );

      RitmoHaptics.success();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${toPersianDigits(selectedSuggestions.length.toString())} برنامه به هفته اضافه شد 🎉',
              style: const TextStyle(),
            ),
          ),
        );
        widget.onApplied?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در چیدن برنامه‌ها: $e',
              style: const TextStyle(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'پر کردن هوشمند هفته ✨',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'پیشنهاد واقعی، بدون برنامهٔ اجباری',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'بستن',
                    icon: const Icon(CupertinoIcons.xmark_circle_fill),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                itemCount: widget.suggestions.length,
                itemBuilder: (context, index) {
                  final s = widget.suggestions[index];
                  final isChecked = _selectedIndices.contains(index);
                  final dayName = kPersianWeekdayNames[s.weekdaySat0];
                  final timeStr =
                      toPersianDigits('${s.suggestedTime.hour.toString().padLeft(2, '0')}:${s.suggestedTime.minute.toString().padLeft(2, '0')}');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isChecked ? colors.primary.withValues(alpha: 0.4) : colors.border,
                        width: isChecked ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Checkbox.adaptive(
                              value: isChecked,
                              activeColor: colors.primary,
                              onChanged: (val) {
                                RitmoHaptics.selection();
                                setState(() {
                                  if (val == true) {
                                    _selectedIndices.add(index);
                                  } else {
                                    _selectedIndices.remove(index);
                                  }
                                });
                              },
                            ),
                            Text(
                              s.kind.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.kind.titleFa,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$dayName · ساعت $timeStr (${toPersianDigits(s.suggestedMinutes.toString())} دقیقه)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                final dartWk = sat0ToDartWeekday(s.weekdaySat0);
                                Navigator.of(context).pop();
                                showMovementPlanSheet(
                                  context,
                                  initialKind: s.kind,
                                  initialDays: [dartWk],
                                  initialDayTimes: {dartWk: s.suggestedTime},
                                  initialDurationMinutes: s.suggestedMinutes,
                                  initialReminderMinutes: s.reminderMinutes,
                                  initialMuscleFocus: s.kind.family == MovementFamily.strength ? 'FULL_BODY' : null,
                                  onSaved: widget.onApplied,
                                );
                              },
                              child: Text(
                                'ویرایش',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.surfaceSunken,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            s.reasonFa,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.4))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF042116),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _selectedIndices.isEmpty || _isApplying
                      ? null
                      : () {
                          RitmoHaptics.tap();
                          _applySelected();
                        },
                  child: _isApplying
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF042116)),
                        )
                      : Text(
                          _selectedIndices.isEmpty
                              ? 'حداقل یک پیشنهاد را انتخاب کن'
                              : 'چیدن ${_selectedIndices.length.toPersianDigits()} جلسه در هفته',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
