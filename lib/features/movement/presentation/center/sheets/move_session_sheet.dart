import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_analytics_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/reason_chip.dart';

/// شیت جابه‌جایی جلسه به روز و ساعت دیگر با انتخاب دامنه و روزهای پیشنهادی
class MoveSessionSheet extends StatefulWidget {
  const MoveSessionSheet({
    super.key,
    required this.occurrence,
    required this.onMoveConfirm,
    this.weekDates = const [],
  });

  final MovementOccurrence occurrence;
  final Future<void> Function(
    String newDateIso,
    String? newTime,
    MovementChangeScope scope,
  )
  onMoveConfirm;
  final List<DateTime> weekDates;

  static Future<bool?> show(
    BuildContext context, {
    required MovementOccurrence occurrence,
    required Future<void> Function(
      String newDateIso,
      String? newTime,
      MovementChangeScope scope,
    )
    onMoveConfirm,
    List<DateTime> weekDates = const [],
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MoveSessionSheet(
        occurrence: occurrence,
        weekDates: weekDates,
        onMoveConfirm: (newDate, newTime, scope) async {
          await onMoveConfirm(newDate, newTime, scope);
          if (ctx.mounted) {
            Navigator.of(ctx).pop(true);
          }
        },
      ),
    );
  }

  @override
  State<MoveSessionSheet> createState() => _MoveSessionSheetState();
}

class _MoveSessionSheetState extends State<MoveSessionSheet> {
  static const _weekdayFullNames = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  late String _selectedDateIso;
  late String _selectedTime;
  MovementChangeScope _scope = MovementChangeScope.onlyThis;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDateIso = widget.occurrence.dateIso;
    _selectedTime = widget.occurrence.startTime ?? '18:30';
  }

  List<DateTime> get _availableDates {
    if (widget.weekDates.isNotEmpty) return widget.weekDates;
    final now = DateTime.now();
    final sat = now.subtract(Duration(days: (now.weekday + 1) % 7));
    return List.generate(7, (i) => sat.add(Duration(days: i)));
  }

  String _formatIso(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int _ritmoWeekday(DateTime d) => (d.weekday + 1) % 7;

  Future<void> _pickTime() async {
    final initial = TimeOfDay(
      hour: int.tryParse(_selectedTime.split(':').first) ?? 18,
      minute: int.tryParse(_selectedTime.split(':').last) ?? 30,
    );

    final picked = await showTimePicker(context: context, initialTime: initial);

    if (picked != null) {
      setState(() {
        _selectedTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      await widget.onMoveConfirm(_selectedDateIso, _selectedTime, _scope);
      final dayOffset =
          DateTime.tryParse(_selectedDateIso)
              ?.difference(
                DateTime.tryParse(widget.occurrence.dateIso) ?? DateTime.now(),
              )
              .inDays ??
          0;
      MovementAnalyticsService.instance.logOccurrenceMoved(
        scope: _scope.name,
        dayOffset: dayOffset,
        actionSource: 'move_session_sheet',
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
            MovementStrings.moveSessionTitle,
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // انتخاب روز
          Text(
            MovementStrings.moveSelectDay,
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // ریل انتخاب روزها با ReasonChip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _availableDates.map((date) {
                final iso = _formatIso(date);
                final isSelected = _selectedDateIso == iso;
                final weekdayIdx = _ritmoWeekday(date);
                final isSuggested = weekdayIdx == 1 || weekdayIdx == 3;

                return Padding(
                  padding: const EdgeInsets.only(left: RitmoSpacing.sm),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _selectedDateIso = iso),
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        child: Container(
                          width: 52,
                          height: 64,
                          decoration: BoxDecoration(
                            color: isSelected ? sportsColor : colors.surface,
                            borderRadius: BorderRadius.circular(
                              RitmoRadius.card,
                            ),
                            border: Border.all(
                              color: isSelected ? sportsColor : colors.border,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _weekdayFullNames[weekdayIdx],
                                style: RitmoTextStyles.caption(
                                  isSelected
                                      ? Colors.white
                                      : colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                toPersianDigits(date.day),
                                style: RitmoTextStyles.cardTitle(
                                  isSelected
                                      ? Colors.white
                                      : colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isSuggested) ...[
                        const SizedBox(height: 4),
                        const ReasonChip(
                          reason: MovementStrings.reasonRecoveryGap,
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // انتخاب ساعت
          Row(
            children: [
              Text(
                MovementStrings.moveSelectTime,
                style: RitmoTextStyles.body(colors.textPrimary),
              ),
              const Spacer(),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(RitmoRadius.field),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: sportsColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                  child: Text(
                    toPersianDigits(_selectedTime),
                    style: RitmoTextStyles.cardTitle(sportsColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // انتخاب دامنهٔ جابه‌جایی
          if (widget.occurrence.templateId != null) ...[
            Text(
              MovementStrings.scopeTitle,
              style: RitmoTextStyles.label(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.xs),
            Wrap(
              spacing: RitmoSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text(MovementStrings.scopeOnlyThis),
                  selected: _scope == MovementChangeScope.onlyThis,
                  selectedColor: sportsColor,
                  onSelected: (s) {
                    if (s)
                      setState(() => _scope = MovementChangeScope.onlyThis);
                  },
                ),
                ChoiceChip(
                  label: const Text(MovementStrings.scopeThisAndFuture),
                  selected: _scope == MovementChangeScope.thisAndFuture,
                  selectedColor: sportsColor,
                  onSelected: (s) {
                    if (s)
                      setState(
                        () => _scope = MovementChangeScope.thisAndFuture,
                      );
                  },
                ),
                ChoiceChip(
                  label: const Text(MovementStrings.scopeWholePlan),
                  selected: _scope == MovementChangeScope.wholePlan,
                  selectedColor: sportsColor,
                  onSelected: (s) {
                    if (s)
                      setState(() => _scope = MovementChangeScope.wholePlan);
                  },
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.lg),
          ],

          // دکمهٔ ثبت
          SizedBox(
            width: double.infinity,
            height: MovementLayout.kFieldMinHeight,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
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
                      MovementStrings.commonConfirm,
                      style: RitmoTextStyles.label(Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],
      ),
    );
  }
}
