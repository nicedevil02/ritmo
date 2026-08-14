import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/analysis/agenda_conflict_detector.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_geometry.dart';

class JourneySuggestionsSection extends StatelessWidget {
  const JourneySuggestionsSection({
    super.key,
    required this.snapshot,
    this.onSelectConflict,
  });

  final DayAgendaSnapshot snapshot;
  final ValueChanged<AgendaConflict>? onSelectConflict;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final conflicts = snapshot.conflicts;
    final suggestions = snapshot.suggestions;

    if (conflicts.isEmpty && suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.xxl),
        alignment: Alignment.center,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.check_circle_outline_rounded, size: 28, color: colors.primary),
            ),
            const SizedBox(height: RitmoSpacing.md),
            Text(
              'برنامه‌ات ایده‌آله 🎯',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.0,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: RitmoSpacing.xs),
            Text(
              'هیچ تداخل یا هشداری در این روز وجود ندارد.',
              style: TextStyle(
                fontSize: 12.0,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conflicts.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: colors.warning),
                const SizedBox(width: RitmoSpacing.sm),
                Text(
                  'تداخل‌ها (${toPersianDigits(conflicts.length.toString())})',
                  style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                    color: colors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.sm),
            for (final conflict in conflicts)
              InkWell(
                onTap: () => onSelectConflict?.call(conflict),
                borderRadius: BorderRadius.circular(RitmoRadius.card),
                child: Container(
                  margin: const EdgeInsets.only(bottom: RitmoSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    border: Border.all(color: colors.warning.withValues(alpha: 0.25)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    child: Row(
                      children: [
                        Container(
                          width: CalendarGeometry.accentBarWidth,
                          height: 54,
                          color: colors.warning,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    conflict.description,
                                    style: TextStyle(
                                      fontSize: 14.0,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.warning,
                                    borderRadius: BorderRadius.circular(RitmoRadius.badge),
                                  ),
                                  child: Text(
                                    'رفع تداخل',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: colors.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: RitmoSpacing.md),
          ],
          if (suggestions.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 18, color: colors.primary),
                const SizedBox(width: RitmoSpacing.sm),
                Text(
                  'پیشنهادها (${toPersianDigits(suggestions.length.toString())})',
                  style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.sm),
            for (final suggestion in suggestions)
              Container(
                margin: const EdgeInsets.only(bottom: RitmoSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  child: Row(
                    children: [
                      Container(
                        width: CalendarGeometry.accentBarWidth,
                        height: 54,
                        color: colors.primary,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  suggestion.message,
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (suggestion.suggestedTimeOfDay != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    borderRadius: BorderRadius.circular(RitmoRadius.badge),
                                  ),
                                  child: Text(
                                    toPersianDigits(suggestion.suggestedTimeOfDay ?? ''),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
