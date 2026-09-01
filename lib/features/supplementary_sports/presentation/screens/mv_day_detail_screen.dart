import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/sheet/ritmo_picker_sheet.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';
import '../sheets/sheets.dart';

/// Screen 7: "جزئیات جلسهٔ روز" (Section 5.8).
class MvDayDetailScreen extends StatefulWidget {
  final MvSlot slot;
  final List<MvExercise> plannedExercises;
  final VoidCallback onStartSession;
  final ValueChanged<MvSlot> onSlotUpdated;
  final void Function(MvSlot slot, bool deleteRecurring)? onDeleteSlot;

  const MvDayDetailScreen({
    super.key,
    required this.slot,
    required this.plannedExercises,
    required this.onStartSession,
    required this.onSlotUpdated,
    this.onDeleteSlot,
  });

  @override
  State<MvDayDetailScreen> createState() => _MvDayDetailScreenState();
}

class _MvDayDetailScreenState extends State<MvDayDetailScreen> {
  late MvSlot _currentSlot;
  late List<MvExercise> _exercises;

  @override
  void initState() {
    super.initState();
    _currentSlot = widget.slot;
    _exercises = List<MvExercise>.from(widget.plannedExercises);
  }

  Future<void> _handleDelete() async {
    final l10n = AppLocalizations.of(context);
    final isLocked = _currentSlot.isLocked;

    if (isLocked) {
      final selected = await RitmoPickerSheet.show<bool>(
        context: context,
        title: l10n?.mv_plan_delete_recurring_prompt ?? 'نحوهٔ حذف ورزش تکرارشونده',
        options: [
          PickerOption(
            label: l10n?.mv_plan_delete_this_week_only ?? 'فقط برای این هفته لغو شود',
            subtitle: 'تعهد هفتگی حفظ شده و این روز به استراحت تبدیل می‌شود.',
            icon: Icons.event_busy_rounded,
            value: false,
          ),
          PickerOption(
            label: l10n?.mv_plan_delete_all_weeks ?? 'حذف دائمی از برنامهٔ هفتگی',
            subtitle: 'کل تعهد هفتگی برای همیشه پاک می‌شود.',
            icon: Icons.delete_forever_rounded,
            value: true,
          ),
        ],
      );

      if (selected == null || !mounted) return;

      if (widget.onDeleteSlot != null) {
        widget.onDeleteSlot!(_currentSlot, selected);
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        final restSlot = _currentSlot.copyWith(
          slotType: MvSlotType.rest,
          kindCode: null,
          targetMinutes: 0,
          plannedTime: null,
          headlineFa: 'روز استراحت و ریکاوری',
          isLocked: true,
          updatedAt: now,
        );
        widget.onSlotUpdated(restSlot);
      }
      if (mounted) Navigator.pop(context);
    } else {
      final confirmed = await RitmoDialog.show(
        context,
        title: l10n?.mv_plan_delete_confirm_title ?? 'حذف برنامهٔ ورزشی',
        content: l10n?.mv_plan_delete_confirm_desc ??
            'آیا از حذف برنامهٔ ورزشی این روز مطمئن هستید؟ این روز به عنوان استراحت ثبت خواهد شد.',
        confirmLabel: l10n?.mv_plan_delete_confirm ?? 'حذف برنامه',
        cancelLabel: l10n?.cancel ?? 'انصراف',
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
      );

      if (confirmed != true || !mounted) return;

      if (widget.onDeleteSlot != null) {
        widget.onDeleteSlot!(_currentSlot, false);
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        final restSlot = _currentSlot.copyWith(
          slotType: MvSlotType.rest,
          kindCode: null,
          targetMinutes: 0,
          plannedTime: null,
          headlineFa: 'روز استراحت و ریکاوری',
          isLocked: true,
          updatedAt: now,
        );
        widget.onSlotUpdated(restSlot);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  void _removeExercise(int index) {
    final removed = _exercises.removeAt(index);
    setState(() {});

    final l10n = AppLocalizations.of(context);
    final msg = l10n != null
        ? l10n.mv_exercise_removed_snackbar(removed.name)
        : 'تمرین ${removed.name} حذف شد';

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.right),
        action: SnackBarAction(
          label: l10n?.mv_undo ?? 'بازگردانی',
          onPressed: () {
            setState(() {
              _exercises.insert(index, removed);
            });
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final dt = MvCalendar.parseDateIso(_currentSlot.dateIso);
    final dayName = MvCalendar.persianWeekdayName(
      MvCalendar.dateTimeToSat0(dt),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('$dayName (${toPersianDigits(_currentSlot.dateIso)})'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: l10n?.mv_day_detail_edit_tooltip ?? 'Edit Day Plan',
            onPressed: () {
              MvDayPlanSheet.show(
                context: context,
                slot: _currentSlot,
                onSave: (s) {
                  setState(() => _currentSlot = s);
                  widget.onSlotUpdated(s);
                },
                onDelete: (s, delRec) {
                  widget.onDeleteSlot?.call(s, delRec);
                  Navigator.pop(context);
                },
              );
            },
          ),
          if (!_currentSlot.isRest)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: colors.error),
              tooltip: l10n?.mv_day_detail_delete_tooltip ?? 'حذف برنامهٔ ورزشی این روز',
              onPressed: _handleDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Headline Hero Card
          RitmoCard.neumorphic(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RitmoCardBadge(
                      label: _currentSlot.slotType.titleFa,
                      color: colors.primary,
                    ),
                    const Spacer(),
                    Text(
                      '${toPersianDigits(_currentSlot.targetMinutes.toString())} ${l10n?.mv_unit_min ?? 'min'}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _currentSlot.headlineFa,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_currentSlot.coachNoteFa != null &&
                    _currentSlot.coachNoteFa!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _currentSlot.coachNoteFa!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Exercise List
          if (!_currentSlot.isRest && _exercises.isNotEmpty) ...[
            Text(
              l10n?.mv_day_detail_session_exercises(_exercises.length) ??
                  'Session Exercises (${_exercises.length})',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_exercises.length, (index) {
              final ex = _exercises[index];
              final repsStr = ex.defaultReps > 0
                  ? (l10n?.mv_day_detail_reps_count(ex.defaultReps) ?? '${ex.defaultReps} reps')
                  : (l10n?.mv_day_detail_timed ?? 'Timed');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RitmoCard.neumorphic(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      RitmoNeuSurface(
                        width: 44,
                        height: 44,
                        radius: 12,
                        padding: EdgeInsets.zero,
                        child: Icon(
                          Icons.fitness_center_rounded,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.name,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${ex.category} · $repsStr',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        tooltip: l10n?.cancel ?? 'حذف حرکت',
                        onPressed: () => _removeExercise(index),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          if (_currentSlot.isRest)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: RitmoNeuEmptyCard(
                icon: Icons.spa_rounded,
                title: 'Active Rest Day',
                subtitle: l10n?.mv_reason_rest_guaranteed ??
                    'Essential rest day for physiological recovery.',
              ),
            ),

          const SizedBox(height: 24),
          if (!_currentSlot.isRest)
            MvPrimaryAction(
              label: l10n?.mv_day_detail_start_session ?? 'Start Today Session',
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                Navigator.pop(context);
                widget.onStartSession();
              },
            ),
        ],
      ),
    );
  }
}
