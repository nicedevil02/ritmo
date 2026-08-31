import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';
import '../sheets/sheets.dart';

/// Screen 7: "جزئیات جلسهٔ روز" (Section 5.8).
class MvDayDetailScreen extends StatelessWidget {
  final MvSlot slot;
  final List<MvExercise> plannedExercises;
  final VoidCallback onStartSession;
  final ValueChanged<MvSlot> onSlotUpdated;

  const MvDayDetailScreen({
    super.key,
    required this.slot,
    required this.plannedExercises,
    required this.onStartSession,
    required this.onSlotUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final dt = MvCalendar.parseDateIso(slot.dateIso);
    final dayName = MvCalendar.persianWeekdayName(
      MvCalendar.dateTimeToSat0(dt),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('$dayName (${toPersianDigits(slot.dateIso)})'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: l10n?.mv_day_detail_edit_tooltip ?? 'Edit Day Plan',
            onPressed: () {
              MvDayPlanSheet.show(
                context: context,
                slot: slot,
                onSave: onSlotUpdated,
              );
            },
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
                      label: slot.slotType.titleFa,
                      color: colors.primary,
                    ),
                    const Spacer(),
                    Text(
                      '${toPersianDigits(slot.targetMinutes.toString())} ${l10n?.mv_unit_min ?? 'min'}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  slot.headlineFa,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (slot.coachNoteFa != null &&
                    slot.coachNoteFa!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    slot.coachNoteFa!,
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
          if (!slot.isRest && plannedExercises.isNotEmpty) ...[
            Text(
              l10n?.mv_day_detail_session_exercises(plannedExercises.length) ??
                  'Session Exercises (${plannedExercises.length})',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...plannedExercises.map((ex) {
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
                    ],
                  ),
                ),
              );
            }),
          ],

          if (slot.isRest)
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
          if (!slot.isRest)
            MvPrimaryAction(
              label: l10n?.mv_day_detail_start_session ?? 'Start Today Session',
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                Navigator.pop(context);
                onStartSession();
              },
            ),
        ],
      ),
    );
  }
}
