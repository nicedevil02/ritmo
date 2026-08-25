import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
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
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final dt = MvCalendar.parseDateIso(slot.dateIso);
    final dayName = MvCalendar.persianWeekdayName(
      MvCalendar.dateTimeToSat0(dt),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('$dayName (${slot.dateIso})'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'ویرایش برنامه',
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
        padding: EdgeInsets.all(metrics.spaceLg),
        children: [
          // Headline Hero Card
          Container(
            padding: EdgeInsets.all(metrics.spaceLg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(metrics.radiusHero),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(RitmoRadius.pill),
                      ),
                      child: Text(
                        slot.slotType.titleFa,
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${slot.targetMinutes} دقیقه',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: metrics.spaceMd),
                Text(
                  slot.headlineFa,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (slot.coachNoteFa != null &&
                    slot.coachNoteFa!.isNotEmpty) ...[
                  SizedBox(height: metrics.spaceSm),
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
          SizedBox(height: metrics.spaceLg),

          // Exercise List
          if (!slot.isRest && plannedExercises.isNotEmpty) ...[
            Text(
              'حرکات این جلسه (${plannedExercises.length} حرکت)',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: metrics.spaceSm),
            ...plannedExercises.map((ex) {
              return Container(
                margin: EdgeInsets.only(bottom: metrics.spaceSm),
                padding: EdgeInsets.all(metrics.spaceMd),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(metrics.radiusCard),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(
                          metrics.radiusField,
                        ),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: colors.primary,
                      ),
                    ),
                    SizedBox(width: metrics.spaceMd),
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
                            '${ex.category} · ${ex.defaultReps > 0 ? "${ex.defaultReps} تکرار" : "زمان‌دار"}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: metrics.spaceLg),
          ],

          if (!slot.isRest && !slot.isCompleted)
            MvPrimaryAction(
              label: 'شروع جلسهٔ تمرینی',
              icon: Icons.play_arrow_rounded,
              onPressed: onStartSession,
            ),
          SizedBox(height: metrics.spaceXxl),
        ],
      ),
    );
  }
}
