// lib/features/wellbeing/presentation/widgets/sleep_target_card.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

/// Collapsible and Overflow-proof Sleep Target Card.
/// Displays target bedtime, wake time, and duration with quick edit access.
class SleepTargetCard extends StatelessWidget {
  const SleepTargetCard({
    super.key,
    required this.target,
    required this.onEditTap,
    this.isExpanded = true,
    this.onToggleExpand,
  });

  final SleepTarget target;
  final VoidCallback onEditTap;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final durationH = target.durationMinutes ~/ 60;
    final durationM = target.durationMinutes % 60;
    final durationText = durationM == 0
        ? '${RitmoNumber.faInt(durationH)} ساعت'
        : '${RitmoNumber.faInt(durationH)} ساعت و ${RitmoNumber.faInt(durationM)} دقیقه';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: RitmoSpacing.md,
        vertical: isExpanded ? RitmoSpacing.md : 10,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(
          color: colors.sleepAccent.withValues(alpha: isExpanded ? 0.28 : 0.18),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : colors.sleepAccent.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row (Guaranteed No Overflow)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              if (onToggleExpand != null) {
                onToggleExpand!();
              } else {
                onEditTap();
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.sleepAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      CupertinoIcons.moon_stars_fill,
                      size: 15,
                      color: colors.sleepAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: isExpanded
                        ? Text(
                            'هدف و زمان‌بندی خواب',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RitmoTextStyles.cardTitle(
                              colors.textPrimary,
                            ).copyWith(fontSize: 13.5),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'هدف: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textSecondary,
                                  ),
                                ),
                                Text(
                                  '${RitmoNumber.fa(target.bedtime)} ⟵ ${RitmoNumber.fa(target.wake)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '($durationText)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: colors.sleepAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),

                  // Quick Action Button
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onEditTap();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.sleepAccent.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.sleepAccent.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.slider_horizontal_3,
                            size: 12,
                            color: colors.sleepAccent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'تنظیم',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: colors.sleepAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (onToggleExpand != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      size: 14,
                      color: colors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Collapsible Detail Section
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            firstCurve: Curves.easeInOutCubic,
            secondCurve: Curves.easeInOutCubic,
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),

                // Bedtime and Wake Time Columns
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeBox(
                        context: context,
                        title: 'ساعت خواب هدف',
                        timeStr: target.bedtime,
                        icon: CupertinoIcons.moon_fill,
                        accentColor: const Color(0xff8B5CF6),
                        colors: colors,
                        onTap: onEditTap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTimeBox(
                        context: context,
                        title: 'ساعت بیداری هدف',
                        timeStr: target.wake,
                        icon: CupertinoIcons.sun_max_fill,
                        accentColor: const Color(0xffF59E0B),
                        colors: colors,
                        onTap: onEditTap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Duration summary footer banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.timer,
                        size: 13,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'مدت خواب مطلوب هدف:',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          durationText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.sleepAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox({
    required BuildContext context,
    required String title,
    required String timeStr,
    required IconData icon,
    required Color accentColor,
    required RitmoColors colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
              width: 0.9,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: accentColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  RitmoNumber.fa(timeStr),
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
