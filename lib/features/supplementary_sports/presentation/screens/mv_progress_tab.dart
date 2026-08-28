import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';

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
    final colors = context.ritmoColors;
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

    return Container(
      padding: EdgeInsets.all(metrics.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        border: Border.all(color: colors.border),
      ),
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
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final load = loadSnapshot;
    if (load == null || !load.hasEnoughData) {
      return MvInsufficientData(
        key: const ValueKey('mv_load_insufficient_data'),
        title: l10n?.mv_training_load_title ?? 'Training Load & Balance',
        requirementDescription: l10n?.mv_training_load_insufficient ??
            'At least 14 days of history and recorded sessions are required to calculate ACWR accurately.',
      );
    }

    Color badgeColor = colors.success;
    if (load.bandKey == 'mv_load_band_watch') {
      badgeColor = colors.warning;
    } else if (load.bandKey == 'mv_load_band_spike') {
      badgeColor = colors.error;
    } else if (load.bandKey == 'mv_load_band_low') {
      badgeColor = colors.textSecondary;
    }

    final ratioVal = load.ratio ?? 1.0;
    final normalizedProgress = (ratioVal / 2.0).clamp(0.0, 1.0);

    return Container(
      key: const ValueKey('mv_training_load_card'),
      padding: EdgeInsets.all(metrics.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        border: Border.all(color: colors.border),
      ),
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
    final colors = context.ritmoColors;
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

    return Container(
      padding: EdgeInsets.all(metrics.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        border: Border.all(color: colors.border),
      ),
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
    final colors = context.ritmoColors;
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

    return Container(
      padding: EdgeInsets.all(metrics.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        border: Border.all(color: colors.border),
      ),
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
    final colors = context.ritmoColors;
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

    return Container(
      key: const ValueKey('mv_active_campaign_card'),
      padding: EdgeInsets.all(metrics.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
      ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                ),
                child: Text(
                  phaseTitle,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('mv_campaign_inactive_card'),
      padding: EdgeInsets.all(metrics.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        border: Border.all(color: colors.border),
      ),
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
          SizedBox(height: metrics.spaceMd),
          ElevatedButton.icon(
            key: const ValueKey('mv_campaign_create'),
            onPressed: () => _openCreateCampaignDialog(context),
            icon: Icon(Icons.add_rounded, size: metrics.iconSm),
            label: Text(l10n?.mv_campaign_create ?? 'Create Training Campaign'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(metrics.radiusField),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openCreateCampaignDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _CreateCampaignDialog(
        onCreate: (campaign) {
          onCreateCampaign?.call(campaign);
        },
      ),
    );
  }

  /// Hero streak
  Widget _buildStreakHero(BuildContext context, int weeks) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: EdgeInsets.all(metrics.spaceLg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(metrics.radiusHero),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(metrics.spaceMd),
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              color: colors.onPrimary,
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
                    color: colors.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
                SizedBox(height: metrics.spaceXs),
                Text(
                  l10n?.mv_streak_weeks_count(toPersianDigits(weeks.toString())) ??
                      '${toPersianDigits(weeks.toString())} weeks',
                  style: textTheme.headlineMedium?.copyWith(
                    color: colors.onPrimary,
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
    final colors = context.ritmoColors;
    final metrics = context.metrics;
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
              size: metrics.iconSm,
            ),
            SizedBox(width: metrics.spaceXs),
            Text(
              l10n?.mv_progress_insights ?? 'Progress Insights',
              style: textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: metrics.spaceSm),
        ...insightsList.map((insight) {
          return Container(
            key: ValueKey(insight.key),
            margin: EdgeInsets.only(bottom: metrics.spaceSm),
            padding: EdgeInsets.all(metrics.spaceMd),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(metrics.radiusCard),
              border: Border.all(color: colors.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(metrics.spaceXs),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(metrics.radiusField),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: metrics.iconSm,
                    color: colors.accent,
                  ),
                ),
                SizedBox(width: metrics.spaceMd),
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
                      SizedBox(height: metrics.spaceXs),
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
          );
        }),
      ],
    );
  }
}

class _CreateCampaignDialog extends StatefulWidget {
  final ValueChanged<MvCampaign> onCreate;

  const _CreateCampaignDialog({required this.onCreate});

  @override
  State<_CreateCampaignDialog> createState() => _CreateCampaignDialogState();
}

class _CreateCampaignDialogState extends State<_CreateCampaignDialog> {
  DateTime _targetDate = DateTime.now().add(const Duration(days: 84)); // 12 weeks
  final String _sportKind = MvKindCodes.hiking;
  final TextEditingController _weightController = TextEditingController(text: '75');
  String? _errorMessage;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final days = _targetDate.difference(DateTime.now()).inDays;
    final weeks = (days / 7).round();

    if (weeks < 4) {
      setState(() {
        _errorMessage = l10n?.mv_campaign_too_short ??
            'Remaining time to event is less than 4 weeks';
      });
      return;
    }

    final now = DateTime.now();
    final campaign = MvCampaign(
      id: 'camp_${now.millisecondsSinceEpoch}',
      titleFa: l10n?.mv_campaign_hiking_title(MvKindCodes.hiking) ?? 'Goal Campaign: Hiking',
      goalCode: _sportKind,
      startDate: MvCalendar.formatDateIso(now),
      weeks: weeks,
      status: 'ACTIVE',
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );

    widget.onCreate(campaign);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(
        l10n?.mv_campaign_create ?? 'Create Training Campaign',
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n?.mv_campaign_target_sport ?? 'Target Sport:', style: textTheme.labelMedium),
            SizedBox(height: metrics.spaceXs),
            Container(
              padding: EdgeInsets.all(metrics.spaceSm),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(metrics.radiusField),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  const Text('🏔️'),
                  SizedBox(width: metrics.spaceSm),
                  Text(
                    l10n?.mv_campaign_hiking_title(MvKindCodes.hiking) ??
                        'Hiking & Trail (${MvKindCodes.hiking})',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            SizedBox(height: metrics.spaceMd),
            Text(l10n?.mv_campaign_target_date ?? 'Target Event Date:', style: textTheme.labelMedium),
            SizedBox(height: metrics.spaceXs),
            InkWell(
              key: const ValueKey('mv_campaign_date_field'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    _targetDate = picked;
                    _errorMessage = null;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.all(metrics.spaceSm),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(metrics.radiusField),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: metrics.iconSm, color: colors.primary),
                    SizedBox(width: metrics.spaceSm),
                    Text(
                      l10n?.mv_campaign_weeks_later(
                            toPersianDigits((_targetDate.difference(DateTime.now()).inDays ~/ 7).toString()),
                            toPersianDigits(MvCalendar.formatDateIso(_targetDate)),
                          ) ??
                          '${_targetDate.difference(DateTime.now()).inDays ~/ 7} weeks later',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: metrics.spaceMd),
            Text(l10n?.mv_campaign_body_weight ?? 'Body Weight (kg):', style: textTheme.labelMedium),
            SizedBox(height: metrics.spaceXs),
            TextField(
              key: const ValueKey('mv_campaign_weight_field'),
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '75',
                filled: true,
                fillColor: colors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(metrics.radiusField),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              SizedBox(height: metrics.spaceSm),
              Text(
                _errorMessage!,
                key: const ValueKey('mv_campaign_error_text'),
                style: textTheme.bodySmall?.copyWith(color: colors.error, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        ElevatedButton(
          key: const ValueKey('mv_campaign_submit_btn'),
          onPressed: _submit,
          child: Text(l10n?.mv_campaign_submit ?? 'Create Campaign'),
        ),
      ],
    );
  }
}
