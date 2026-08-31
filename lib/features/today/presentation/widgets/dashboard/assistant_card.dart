import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/ai/ai_briefing_service.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/daily_behavior.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/assistant/logic/assistant_action_registry.dart';
import 'package:ritmo/features/assistant/models/assistant_models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// کارت دستیار یکپارچه: ادغام «بنر دستیار هوشمند» (پیشنهاد بهترین اقدام بعدی)
/// و «تحلیل هوشمند» (بریفینگ AI) در یک کارت واحد متصل به سامانه مرجع کارت‌های ریتمو.
class AssistantCard extends StatelessWidget {
  const AssistantCard({
    super.key,
    this.subtitle,
    required this.suggestedRoutine,
    required this.suggestLightVersion,
    required this.activeZoneName,
    required this.defaultEnergyLevel,
    required this.dailyBehavior,
    required this.onStartTap,
    required this.onWhyTap,
    required this.briefing,
    required this.isBriefingLoading,
    required this.onRefreshBriefing,
    // P1-3: وقتی false است، بخش «بهترین اقدام بعدی» رندر نمیشود؛
    // صفحهٔ اصلی false پاس میدهد چون NextActionHero صاحب اقدام اصلی است (H-3).
    this.showNextAction = true,
  });

  final String? subtitle;

  // پیشنهاد هوشمند (AssistantBanner سابق)
  final Routine? suggestedRoutine;
  final bool suggestLightVersion;
  final String activeZoneName;
  final String defaultEnergyLevel;
  final DailyBehavior? dailyBehavior;
  final Function(Routine) onStartTap;
  final Function(String) onWhyTap;

  // بریفینگ AI (AiBriefingCard سابق)
  final AiBriefing? briefing;
  final bool isBriefingLoading;
  final VoidCallback onRefreshBriefing;

  // P1-3: نمایش/عدمنمایش بخش «بهترین اقدام بعدی» (پیشفرض: true برای سازگاری)
  final bool showNextAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final hasNext = suggestedRoutine != null;
    final titleText = hasNext ? suggestedRoutine!.title : l10n.restAndRecovery;
    final durationText = hasNext
        ? (suggestLightVersion
            ? l10n.minutesLight(suggestedRoutine!.lightDurationMinutes ??
                suggestedRoutine!.targetDurationMinutes ??
                30)
            : l10n.minutes(suggestedRoutine!.targetDurationMinutes ?? 30))
        : l10n.freeTime;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoCard.neumorphic(
        padding: const EdgeInsets.all(RitmoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── هدر مرجع نئومورفیک با تایتل، زیرعنوان و دکمه ریفرش ──
            RitmoCardHeader(
              title: l10n.smartAssistantTitle,
              subtitle: subtitle ?? 'خلاصهٔ امروز و پیشنهاد بعدی',
              icon: CupertinoIcons.sparkles,
              iconColor: colors.primary,
              trailing: Semantics(
                button: true,
                label: 'به‌روزرسانی تحلیل هوشمند',
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                  onPressed: () {
                    RitmoHaptics.tap();
                    onRefreshBriefing();
                  },
                  child: Icon(
                    CupertinoIcons.arrow_clockwise,
                    color: colors.iconSecondary,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const RitmoCardDivider(),
            const SizedBox(height: 12),

              // ── بهترین اقدام بعدی ──
              // P1-3: در صفحهٔ اصلی مخفی است — hero صاحب اقدام اصلی است (H-3)
              if (showNextAction) ...[
              Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(RitmoRadius.card),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      hasNext
                          ? CupertinoIcons.bolt_fill
                          : CupertinoIcons.moon_zzz_fill,
                      color: colors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.bestNextAction,
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textSecondary,
                            ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RitmoTextStyles.cardTitle(colors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(CupertinoIcons.time,
                                size: 10, color: colors.textSecondary),
                            const SizedBox(width: RitmoSpacing.xs),
                            Text(
                              durationText,
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.textSecondary,
                                ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RitmoSpacing.lg),

              // ── دکمه‌ها ──
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(RitmoRadius.card),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: hasNext
                          ? () {
                              RitmoHaptics.confirm();
                              onStartTap(suggestedRoutine!);
                            }
                          : null,
                      icon: const Icon(CupertinoIcons.play_arrow_solid,
                          size: 12),
                      label: Text(
                        l10n.start,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          ),
                      ),
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(RitmoRadius.card),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => onWhyTap(titleText),
                      child: Text(
                        l10n.whyThisSuggestion,
                        style: const TextStyle(
                            fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              ] else if (suggestedRoutine != null) ...[
                // P1-3: در حالت مخفی، دسترسی به توضیح موتور حفظ میشود
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => onWhyTap(titleText),
                    icon: Icon(CupertinoIcons.question_circle,
                        size: 14, color: colors.textSecondary),
                    label: Text(
                      l10n.whyThisSuggestion,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                        ),
                    ),
                  ),
                ),
              ],

              // ── بریفینگ AI (شرطی) ──
              // ── بریفینگ AI (شرطی) ──
              if (isBriefingLoading) ...[
                const SizedBox(height: 12),
                const RitmoCardSkeleton(height: 70),
              ] else if (briefing != null) ...[
                const SizedBox(height: 12),
                const RitmoCardDivider(),
                const SizedBox(height: 12),
                _buildBriefing(context, briefing!),
              ],
            ],
          ),
        ),
      );
    }

  Widget _buildBriefing(BuildContext context, AiBriefing b) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (b.headline.isNotEmpty) ...[
          Text(
            b.headline,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Vazirmatn',
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: RitmoSpacing.sm),
        ],
        if (b.summary.isNotEmpty) ...[
          Text(
            b.summary,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              fontFamily: 'Vazirmatn',
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: RitmoSpacing.sm),
        ],
        if (b.insights.isNotEmpty) ...[
          ...b.insights.map((insight) => _buildInsightRow(context, insight)),
          const SizedBox(height: RitmoSpacing.sm),
        ],
        if (b.suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Column(
            children: b.suggestions
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildSuggestion(context, s),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildInsightRow(BuildContext context, BriefingInsight insight) {
    final colors = context.colors;
    var dotColor = colors.primary;
    if (insight.tone == 'positive') {
      dotColor = colors.success;
    } else if (insight.tone == 'attention') {
      dotColor = colors.warning;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: RitmoSpacing.sm),
          Expanded(
            child: Text(
              insight.text,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Vazirmatn',
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestion(BuildContext context, BriefingSuggestion suggestion) {
    final colors = context.colors;
    final actionType = AssistantActionType.tryFromString(suggestion.actionType);

    if (actionType == null) {
      return RitmoCard.neumorphicSunken(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            suggestion.text,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Vazirmatn',
              color: colors.textSecondary,
            ),
          ),
        ),
      );
    }

    return RitmoCard.neumorphicSunken(
      onTap: () {
        RitmoHaptics.selection();
        final action = AssistantAction(
          type: actionType,
          title: suggestion.text,
          payload: suggestion.payload ?? {},
        );
        AssistantActionRegistry.executeAction(context, action, () {
          debugPrint(
              '[ASSISTANT_CARD] Action executed: ${suggestion.actionType}');
        });
      },
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              suggestion.text,
              style: TextStyle(
                fontSize: 12,
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontFamily: 'Vazirmatn',
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(actionType.icon, size: 16, color: colors.primary),
        ],
      ),
    );
  }
}
