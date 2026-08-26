import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';
import '../sheets/sheets.dart';
import 'mv_commitments_screen.dart';

/// Tab 2: "هفته" (Section 5.2).
/// Displays 7 day cards for the week and cycle progress.
class MvWeekTab extends StatelessWidget {
  final List<MvSlot> weekSlots;
  final int cycleWeek;
  final bool isDeloadWeek;
  final List<MvCommitment> commitments;
  final MvKindUseCase? kindUseCase;
  final ValueChanged<MvSlot> onSlotUpdated;
  final VoidCallback onRegenerateWeek;
  final VoidCallback? onOpenCommitments;

  const MvWeekTab({
    super.key,
    required this.weekSlots,
    required this.cycleWeek,
    this.isDeloadWeek = false,
    this.commitments = const [],
    this.kindUseCase,
    required this.onSlotUpdated,
    required this.onRegenerateWeek,
    this.onOpenCommitments,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(metrics.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Week Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.mv_week_title(cycleWeek),
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: metrics.spaceXs),
                  Text(
                    isDeloadWeek
                        ? l10n.mv_week_deload_subtitle
                        : l10n.mv_week_regular_subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (isDeloadWeek)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.spaceSm,
                    vertical: metrics.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                  child: Text(
                    l10n.mv_week_deload_badge,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // Anchor CTA Card if no commitments (S8-T4)
          if (commitments.isEmpty) ...[
            InkWell(
              key: const ValueKey('mv_week_anchor_cta'),
              onTap: onOpenCommitments ??
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MvCommitmentsScreen(),
                      ),
                    );
                  },
              borderRadius: BorderRadius.circular(metrics.radiusCard),
              child: Container(
                padding: EdgeInsets.all(metrics.spaceMd),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(metrics.radiusCard),
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_clock,
                      color: colors.accent,
                      size: metrics.iconMd,
                    ),
                    SizedBox(width: metrics.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.mv_week_anchor_cta,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          SizedBox(height: metrics.spaceXs),
                          Text(
                            l10n.mv_week_anchor_cta_text,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: metrics.iconSm,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: metrics.spaceMd),
          ],

          // Back-to-Back Conflict Banner (S2-T6, ADJ-6)
          if (_hasBackToBackAnchors(weekSlots)) ...[
            Container(
              key: const ValueKey('mv_conflict_back_to_back'),
              padding: EdgeInsets.all(metrics.spaceMd),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(metrics.radiusCard),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: colors.warning,
                    size: metrics.iconSm,
                  ),
                  SizedBox(width: metrics.spaceSm),
                  Expanded(
                    child: Text(
                      l10n.mv_conflict_back_to_back,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: metrics.spaceMd),
          ],

          // 7 Day Slot Cards
          ...List.generate(weekSlots.length, (index) {
            final slot = weekSlots[index];
            return Padding(
              padding: EdgeInsets.only(bottom: metrics.spaceSm),
              child: MvDaySlotCard(
                slot: slot,
                onTap: () {
                  MvDayPlanSheet.show(
                    context: context,
                    slot: slot,
                    kindUseCase: kindUseCase,
                    onSave: onSlotUpdated,
                  );
                },
              ),
            );
          }),
          SizedBox(height: metrics.spaceMd),

          // Smart Fill / Re-align Action
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, metrics.touchTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(metrics.radiusField),
              ),
            ),
            icon: Icon(Icons.auto_fix_high_rounded, size: metrics.iconMd),
            label: Text(l10n.mv_week_regenerate),
            onPressed: onRegenerateWeek,
          ),
          SizedBox(height: metrics.spaceXxl),
        ],
      ),
    );
  }

  bool _hasBackToBackAnchors(List<MvSlot> slots) {
    if (slots.length < 2) return false;
    final sorted = List<MvSlot>.from(slots)
      ..sort((a, b) => a.dateIso.compareTo(b.dateIso));
    for (int i = 0; i < sorted.length - 1; i++) {
      final current = sorted[i];
      final next = sorted[i + 1];
      final isCurrentAnchor = (current.source == 'ANCHOR' || current.isLocked) && !current.isRest;
      final isNextAnchor = (next.source == 'ANCHOR' || next.isLocked) && !next.isRest;
      if (isCurrentAnchor && isNextAnchor) {
        return true;
      }
    }
    return false;
  }
}
