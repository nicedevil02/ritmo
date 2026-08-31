import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';
import '../sheets/sheets.dart';

/// Tab 3: "پیشرفت" (Section 5.3 / S5-T4).
/// Displays 5 structured sections with dual-currency WHO budget, ACWR load,
/// monthly kind mix distribution, partitioned personal records, and active campaign.
class MvProgressTab extends StatelessWidget {
  final int? continuousActiveWeeks;
  final int totalSessionsCount;
  final double totalMetMinutes;
  final MvWeeklyBudgetProgress? weeklyBudget;
  final MvLoadSnapshot? loadSnapshot;
  final Map<String, int>? monthlyKindMinutes;
  final Map<String, MvMovementKind>? kindsMap;
  final List<MvPersonalRecord> personalRecords;
  final List<MvInsight> insights;
  final MvCampaign? activeCampaign;
  final MvBodyMapDistribution? bodyMapDistribution;
  final bool hasEnoughDataForTrends;
  final ValueChanged<MvCampaign>? onCreateCampaign;

  const MvProgressTab({
    super.key,
    this.continuousActiveWeeks,
    this.totalSessionsCount = 0,
    this.totalMetMinutes = 0.0,
    this.weeklyBudget,
    this.loadSnapshot,
    this.monthlyKindMinutes,
    this.kindsMap,
    this.personalRecords = const [],
    this.insights = const [],
    this.activeCampaign,
    this.bodyMapDistribution,
    this.hasEnoughDataForTrends = false,
    this.onCreateCampaign,
    this.topPadding = 16.0,
  });

  final double topPadding;

  @override
  Widget build(BuildContext context) {
    final metrics = context.metrics;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(10, topPadding, 10, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. کارت «سلامت این هفته» (WHO Dual Currency Budget)
          _buildWeeklyHealthCard(context),
          const SizedBox(height: 16),

          // 2. کارت «بار تمرینی» (ACWR Training Load)
          _buildTrainingLoadCard(context),
          const SizedBox(height: 16),

          // 3. کارت «توزیع ورزش‌ها» (Monthly Kind Distribution)
          _buildKindDistributionCard(context),
          const SizedBox(height: 16),

          // 4. کارت «رکوردها به تفکیک نوع» (Partitioned PRs)
          _buildPersonalRecordsCard(context),
          const SizedBox(height: 16),

          // 5. بینش‌های پیشرفت بر مبنای قوانین مشخص (InsightEngine / S8-T8)
          if (insights.isNotEmpty) ...[
            _buildInsightsSection(context, insights),
            const SizedBox(height: 16),
          ],

          // 6. دورهٔ هدف‌دار (Active or Inactive CTA) (CampaignEngine / S8-T9)
          if (activeCampaign != null && activeCampaign!.isActive) ...[
            _buildActiveCampaignCard(context, activeCampaign!),
          ] else ...[
            _buildInactiveCampaignCard(context),
          ],
          const SizedBox(height: 16),

          // 7. هفته‌های فعال پیوسته (Hero streak)
          if (continuousActiveWeeks != null && continuousActiveWeeks! > 0) ...[
            _buildStreakHero(context, continuousActiveWeeks!),
            const SizedBox(height: 16),
          ],

          SizedBox(height: metrics.spaceXxl),
        ],
      ),
    );
  }

  /// 1. کارت سلامت این هفته (دقیقهٔ معادل متوسط / ۱۵۰ و تعداد روز قدرتی / ۲)
  Widget _buildWeeklyHealthCard(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final budget = weeklyBudget;
    if (budget == null ||
        (budget.moderateEquivalentMinutes == 0 && budget.strengthDays == 0)) {
      return MvInsufficientData(
        title: l10n?.mv_weekly_health_title ?? 'Weekly Health',
        requirementDescription: l10n?.mv_weekly_health_empty ??
            'No activity recorded this week. Progress will appear once your first session is saved.',
      );
    }

    final modMinutes = budget.moderateEquivalentMinutes;
    final targetMod = budget.targetMin > 0 ? budget.targetMin : 150;
    final modProgress = (modMinutes / targetMod).clamp(0.0, 1.5);

    final targetStr =
        budget.strengthDaysTarget > 0 ? budget.strengthDaysTarget : 2;
    final strDays = budget.strengthDays;
    final strProgress = (strDays / targetStr).clamp(0.0, 1.5);

    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                color: colors.error,
                size: metrics.iconMd,
              ),
              SizedBox(width: metrics.spaceSm),
              Text(
                l10n?.mv_weekly_health_who ?? 'Weekly Health (WHO Guidelines)',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceMd),

          // Moderate equivalent minutes bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.mv_weekly_health_moderate ?? 'Moderate-Intensity Equivalent',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                l10n?.mv_weekly_health_min_progress(
                      toPersianDigits(modMinutes.toString()),
                      toPersianDigits(targetMod.toString()),
                    ) ??
                    '${toPersianDigits(modMinutes.toString())} / ${toPersianDigits(targetMod.toString())} min',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: modProgress > 1.0 ? 1.0 : modProgress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              minHeight: 8,
            ),
          ),
          SizedBox(height: metrics.spaceMd),

          // Strength days bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.mv_weekly_health_strength ?? 'Strength & Resistance Days',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                l10n?.mv_weekly_health_day_progress(
                      toPersianDigits(strDays.toString()),
                      toPersianDigits(targetStr.toString()),
                    ) ??
                    '${toPersianDigits(strDays.toString())} / ${toPersianDigits(targetStr.toString())} days',
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: strProgress > 1.0 ? 1.0 : strProgress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  /// 2. کارت بار تمرینی (۷ روز در برابر میانگین ۲۸ روز + نسبت ACWR)
  Widget _buildTrainingLoadCard(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final load = loadSnapshot;
    if (load == null || load.acuteLoad == 0.0) {
      return MvInsufficientData(
        title: 'Training Load (ACWR)',
        requirementDescription: l10n?.mv_insufficient_data_generic ??
            'Requires at least 7 days of activity to calculate Acute:Chronic Workload Ratio.',
      );
    }

    final Color badgeColor;
    if (load.bandKey == 'mv_load_band_optimal') {
      badgeColor = colors.success;
    } else if (load.bandKey == 'mv_load_band_high') {
      badgeColor = colors.warning;
    } else if (load.bandKey == 'mv_load_band_spike') {
      badgeColor = colors.error;
    } else if (load.bandKey == 'mv_load_band_low') {
      badgeColor = colors.textSecondary;
    } else {
      badgeColor = colors.primary;
    }

    final ratioVal = load.ratio ?? 1.0;
    final normalizedProgress = (ratioVal / 2.0).clamp(0.0, 1.0);

    return RitmoCard.neumorphic(
      key: const ValueKey('mv_training_load_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.speed_rounded,
                    color: colors.primary,
                    size: metrics.iconMd,
                  ),
                  SizedBox(width: metrics.spaceSm),
                  Text(
                    l10n?.mv_training_load_card_title ?? 'Training Load (7-day to 28-day)',
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                key: ValueKey(load.bandKey ?? 'mv_load_band_badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  load.bandTitleFa,
                  style: textTheme.labelSmall?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceMd),
          Row(
            children: [
              Expanded(
                child: MvStatTile(
                  title: l10n?.mv_training_load_acute ?? 'Acute Load (7-day)',
                  value: toPersianDigits(load.acuteLoad.toString()),
                  unit: 'sRPE',
                  icon: Icons.bolt_rounded,
                ),
              ),
              SizedBox(width: metrics.spaceMd),
              Expanded(
                child: MvStatTile(
                  title: l10n?.mv_training_load_chronic ?? 'Chronic 28-day Weekly Avg',
                  value: toPersianDigits(load.chronicWeeklyLoad.round().toString()),
                  unit: 'sRPE',
                  icon: Icons.timeline_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceMd),

          // Load ratio progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: normalizedProgress,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
              minHeight: 8,
            ),
          ),
          SizedBox(height: metrics.spaceSm),
          Text(
            l10n?.mv_training_load_summary(
                  toPersianDigits(load.ratio!.toStringAsFixed(2)),
                  load.bandTitleFa,
                ) ??
                'Over the past 4 weeks, your acute-to-chronic workload ratio is ${load.ratio!.toStringAsFixed(2)} (${load.bandTitleFa}).',
            key: const ValueKey('mv_load_ratio_text'),
            style: textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// 3. کارت توزیع ورزش‌ها (سهم هر نوع از دقیقهٔ ماه جاری)
  Widget _buildKindDistributionCard(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final kindMinutes = monthlyKindMinutes;
    if (kindMinutes == null || kindMinutes.isEmpty) {
      return MvInsufficientData(
        title: l10n?.mv_kind_distribution_title ?? 'Monthly Sport Distribution',
        requirementDescription: l10n?.mv_kind_distribution_insufficient ??
            'At least one recorded session is required to show distribution this month.',
      );
    }

    final totalMin = kindMinutes.values.fold(0, (a, b) => a + b);
    final sorted = kindMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_rounded,
                color: colors.primary,
                size: metrics.iconMd,
              ),
              SizedBox(width: metrics.spaceSm),
              Text(
                l10n?.mv_kind_distribution_card_title ?? 'Current Month Sport Distribution',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceMd),
          ...sorted.take(4).map((entry) {
            final kind = kindsMap?[entry.key];
            final title = kind?.titleFa ?? entry.key;
            final emoji = kind?.emoji ?? '🏃';
            final pct = totalMin > 0 ? (entry.value / totalMin) : 0.0;

            return Padding(
              padding: EdgeInsets.only(bottom: metrics.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(emoji, style: textTheme.bodyMedium),
                          SizedBox(width: metrics.spaceXs),
                          Text(
                            title,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        l10n?.mv_kind_distribution_progress(
                              toPersianDigits(entry.value.toString()),
                              toPersianDigits((pct * 100).toInt().toString()),
                            ) ??
                            '${entry.value} min (${(pct * 100).toInt()}%)',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: metrics.spaceXs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (sorted.isNotEmpty) ...[
            SizedBox(height: metrics.spaceXs),
            Text(
              l10n?.mv_kind_distribution_focus(kindsMap?[sorted.first.key]?.titleFa ?? sorted.first.key) ??
                  'Your main activity focus has been on ${kindsMap?[sorted.first.key]?.titleFa ?? sorted.first.key}.',
              style: textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 4. کارت رکوردها به تفکیک نوع (Partitioned PRs)
  Widget _buildPersonalRecordsCard(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    if (personalRecords.isEmpty) {
      return MvInsufficientData(
        title: l10n?.mv_pr_title ?? 'Personal Records',
        requirementDescription: l10n?.mv_pr_empty_desc ??
            'No records yet. As you finish workout sessions, new PRs will show here.',
      );
    }

    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: colors.warning,
                size: metrics.iconMd,
              ),
              SizedBox(width: metrics.spaceSm),
              Text(
                l10n?.mv_pr_by_sport ?? 'Personal Records by Sport',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceMd),
          ...personalRecords.take(5).map((pr) {
            final kind = kindsMap?[pr.kind];
            final displayKind = kind != null ? '${kind.emoji} ${kind.titleFa}' : pr.kind;
            return Container(
              margin: EdgeInsets.only(bottom: metrics.spaceSm),
              padding: EdgeInsets.symmetric(
                horizontal: metrics.spaceMd,
                vertical: metrics.spaceSm,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(metrics.radiusField),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    displayKind,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    toPersianDigits(pr.formattedValue),
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 5. دورهٔ هدف‌دار فعال (Active Goal Campaign)
  Widget _buildActiveCampaignCard(BuildContext context, MvCampaign campaign) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final start = DateTime.tryParse(campaign.startDate) ?? DateTime.now();
    final currentWeek = ((DateTime.now().difference(start).inDays / 7).floor() + 1).clamp(1, campaign.weeks);
    const engine = CampaignEngine();
    final plan = engine.buildOutdoorPlan(totalWeeks: campaign.weeks, bodyWeightKg: 75.0);
    final weekPlan = plan.getWeekPlan(currentWeek);

    String phaseTitle = l10n?.mv_campaign_phase_base ?? 'Base';
    if (l10n != null) {
      if (weekPlan?.phase == MvCampaignPhase.base) {
        phaseTitle = l10n.mv_campaign_phase_base;
      } else if (weekPlan?.phase == MvCampaignPhase.taper) {
        phaseTitle = l10n.mv_campaign_phase_taper;
      } else {
        phaseTitle = l10n.mv_campaign_phase_build;
      }
    }

    final packWeight = weekPlan?.packWeightKg ?? 0.0;

    return RitmoCard.neumorphic(
      key: const ValueKey('mv_active_campaign_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_rounded,
                    color: colors.primary,
                    size: metrics.iconMd,
                  ),
                  SizedBox(width: metrics.spaceSm),
                  Text(
                    l10n?.mv_campaign_active_header ?? 'Active Goal Campaign',
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              RitmoCardBadge(
                label: phaseTitle,
                color: colors.primary,
              ),
            ],
          ),
          SizedBox(height: metrics.spaceSm),
          Text(
            campaign.titleFa,
            style: textTheme.headlineSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: metrics.spaceXs),
          Text(
            l10n != null
                ? l10n.mv_campaign_active_phase(phaseTitle, currentWeek, campaign.weeks)
                : 'Phase $phaseTitle • Week $currentWeek of ${campaign.weeks}',
            key: const ValueKey('mv_campaign_phase_text'),
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          if (packWeight > 0) ...[
            SizedBox(height: metrics.spaceXs),
            Text(
              l10n?.mv_campaign_pack_weight_label(toPersianDigits(packWeight.toStringAsFixed(1))) ??
                  'Target pack weight this week: $packWeight kg',
              key: const ValueKey('mv_campaign_pack_weight'),
              style: textTheme.bodySmall?.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 5b. کارت دورهٔ هدف‌دار غیرفعال (CTA ساخت دوره)
  Widget _buildInactiveCampaignCard(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return RitmoCard.neumorphic(
      key: const ValueKey('mv_campaign_inactive_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag_outlined,
                color: colors.primary,
                size: metrics.iconMd,
              ),
              SizedBox(width: metrics.spaceSm),
              Text(
                l10n?.mv_campaign_title ?? 'Goal Campaign',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceSm),
          Text(
            l10n?.mv_campaign_inactive_desc ?? 'Reverse planning and training for sports event (hiking, trail, etc.)',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          RitmoNeuButton(
            key: const ValueKey('mv_campaign_create'),
            onTap: () => _openCreateCampaignSheet(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  l10n?.mv_campaign_create ?? 'Create Training Campaign',
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCreateCampaignSheet(BuildContext context) {
    MvCreateCampaignSheet.show(
      context: context,
      onCreate: (campaign) {
        onCreateCampaign?.call(campaign);
      },
    );
  }

  /// Hero streak
  Widget _buildStreakHero(BuildContext context, int weeks) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return RitmoCard.neumorphic(
      padding: EdgeInsets.all(metrics.spaceLg),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(metrics.spaceMd),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              color: colors.primary,
              size: metrics.iconLg,
            ),
          ),
          SizedBox(width: metrics.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.mv_streak_continuous_weeks ?? 'Active Continuous Weeks',
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: metrics.spaceXs),
                Text(
                  l10n?.mv_streak_weeks_count(toPersianDigits(weeks.toString())) ??
                      '${toPersianDigits(weeks.toString())} weeks',
                  style: textTheme.headlineMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// بینش‌های پیشرفت (InsightEngine / S8-T8)
  Widget _buildInsightsSection(
    BuildContext context,
    List<MvInsight> insightsList,
  ) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      key: const ValueKey('mv_insights_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              color: colors.accent,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              l10n?.mv_progress_insights ?? 'Progress Insights',
              style: textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...insightsList.map((insight) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RitmoCard.neumorphic(
              key: ValueKey(insight.key),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: colors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.titleFa,
                          style: textTheme.labelLarge?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          insight.descriptionFa,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            height: 1.4,
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
    );
  }
}
