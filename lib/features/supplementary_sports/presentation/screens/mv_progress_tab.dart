import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
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
  final MvCampaign? activeCampaign;
  final MvBodyMapDistribution? bodyMapDistribution;
  final bool hasEnoughDataForTrends;

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
    this.activeCampaign,
    this.bodyMapDistribution,
    this.hasEnoughDataForTrends = false,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = context.metrics;

    return SingleChildScrollView(
      padding: EdgeInsets.all(metrics.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. کارت «سلامت این هفته» (WHO Dual Currency Budget)
          _buildWeeklyHealthCard(context),
          SizedBox(height: metrics.spaceLg),

          // 2. کارت «بار تمرینی» (ACWR Training Load)
          _buildTrainingLoadCard(context),
          SizedBox(height: metrics.spaceLg),

          // 3. کارت «توزیع ورزش‌ها» (Monthly Kind Distribution)
          _buildKindDistributionCard(context),
          SizedBox(height: metrics.spaceLg),

          // 4. کارت «رکوردها به تفکیک نوع» (Partitioned PRs)
          _buildPersonalRecordsCard(context),
          SizedBox(height: metrics.spaceLg),

          // 5. دورهٔ هدف‌دار فعال (Active Goal Campaign)
          if (activeCampaign != null && activeCampaign!.isActive) ...[
            _buildActiveCampaignCard(context, activeCampaign!),
            SizedBox(height: metrics.spaceLg),
          ],

          // 6. هفته‌های فعال پیوسته (Hero streak)
          if (continuousActiveWeeks != null && continuousActiveWeeks! > 0) ...[
            _buildStreakHero(context, continuousActiveWeeks!),
            SizedBox(height: metrics.spaceLg),
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

    final budget = weeklyBudget;
    if (budget == null ||
        (budget.moderateEquivalentMinutes == 0 && budget.strengthDays == 0)) {
      return const MvInsufficientData(
        title: 'سلامت این هفته',
        requirementDescription:
            'هنوز در این هفته فعالیتی ثبت نشده است. با ثبت اولین جلسه، پیشرفت نمایش داده می‌شود.',
      );
    }

    final modMinutes = budget.moderateEquivalentMinutes;
    final targetMod = budget.targetMin > 0 ? budget.targetMin : 150;
    final modProgress = (modMinutes / targetMod).clamp(0.0, 1.5);

    final strDays = budget.strengthDays;
    final targetStr = budget.strengthDaysTarget > 0
        ? budget.strengthDaysTarget
        : 2;
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
                color: colors.primary,
                size: metrics.iconMd,
              ),
              SizedBox(width: metrics.spaceSm),
              Text(
                'سلامت این هفته (توصیه بهداشت جهانی)',
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
                'فعالیت معادل متوسط',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                '${toPersianDigits(modMinutes)} / ${toPersianDigits(targetMod)} دقیقه',
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
                'روزهای قدرتی و مقاومتی',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                '${toPersianDigits(strDays)} / ${toPersianDigits(targetStr)} روز',
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

    final load = loadSnapshot;
    if (load == null || !load.hasEnoughData) {
      return const MvInsufficientData(
        key: ValueKey('mv_load_insufficient_data'),
        title: 'بار تمرینی و تعادل فشار',
        requirementDescription:
            'حداقل ۱۴ روز سابقه و ۶ جلسه تمرین لازم است تا نسبت بار حاد به مزمن (ACWR) به درستی محاسبه شود.',
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
                    'بار تمرینی (۷ روز به ۲۸ روز)',
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
                  title: 'بار حاد (۷ روز)',
                  value: toPersianDigits(load.acuteLoad),
                  unit: 'sRPE',
                  icon: Icons.bolt_rounded,
                ),
              ),
              SizedBox(width: metrics.spaceMd),
              Expanded(
                child: MvStatTile(
                  title: 'میانگین هفتگی ۲۸ روز',
                  value: toPersianDigits(load.chronicWeeklyLoad.round()),
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
            'نسبت بار حاد به مزمن: ${toPersianDigits(load.ratio!.toStringAsFixed(2))} · محدودهٔ ${load.bandTitleFa}',
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

    final kindMinutes = monthlyKindMinutes;
    if (kindMinutes == null || kindMinutes.isEmpty) {
      return const MvInsufficientData(
        title: 'توزیع ورزش‌ها در این ماه',
        requirementDescription:
            'برای نمایش سهم ورزش‌ها، حداقل به ثبت یک جلسه تمرین در ماه جاری نیاز است.',
      );
    }

    final totalMinutes = kindMinutes.values.fold<int>(0, (a, b) => a + b);
    if (totalMinutes == 0) {
      return const MvInsufficientData(
        title: 'توزیع ورزش‌ها در این ماه',
        requirementDescription: 'هنوز فعالیتی در ماه جاری ثبت نشده است.',
      );
    }

    final sortedEntries = kindMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEntry = sortedEntries.first;
    final topKind = kindsMap?[topEntry.key.toUpperCase()];
    final topName = topKind?.titleFa ?? topEntry.key;

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
                'توزیع ورزش‌ها در ماه جاری',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceMd),
          ...sortedEntries.map((e) {
            final kind = kindsMap?[e.key.toUpperCase()];
            final title = kind?.titleFa ?? e.key;
            final emoji = kind?.emoji ?? '🏃';
            final percent = (e.value / totalMinutes * 100).round();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$emoji $title',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${toPersianDigits(percent)}٪ (${toPersianDigits(e.value)} دقیقه)',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100.0,
                      backgroundColor: colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: metrics.spaceSm),
          Text(
            'در ماه گذشته به نظر می‌رسد بیشترین تمرکز فعالیت شما بر $topName بوده است.',
            style: textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// 4. کارت رکوردهای شخصی به تفکیک نوع
  Widget _buildPersonalRecordsCard(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    if (personalRecords.isEmpty) {
      return const MvInsufficientData(
        title: 'رکوردهای شخصی',
        requirementDescription:
            'با انجام اولین جلسهٔ تمرینی، رکوردهایت به تفکیک نوع ورزش اینجا ثبت می‌شود.',
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
                'رکوردهای شخصی به تفکیک ورزش',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceMd),
          ...personalRecords.map((pr) {
            final kind = kindsMap?[pr.kind.toUpperCase()];
            final title = kind != null
                ? '${kind.emoji} ${kind.titleFa}'
                : (pr.isExercisePr ? pr.exerciseId : pr.kind);

            return Container(
              margin: EdgeInsets.only(bottom: metrics.spaceSm),
              padding: EdgeInsets.all(metrics.spaceMd),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(metrics.radiusCard),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.military_tech_rounded,
                    color: colors.warning,
                    size: metrics.iconMd,
                  ),
                  SizedBox(width: metrics.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          pr.prType.titleFa,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
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

    return Container(
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
            children: [
              Icon(
                Icons.flag_rounded,
                color: colors.primary,
                size: metrics.iconMd,
              ),
              SizedBox(width: metrics.spaceSm),
              Text(
                'دورهٔ هدف‌دار فعال',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
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
            'مدت کل: ${toPersianDigits(campaign.weeks)} هفته | شروع از: ${toPersianDigits(campaign.startDate)}',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// Hero streak
  Widget _buildStreakHero(BuildContext context, int weeks) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

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
                  'هفته‌های فعال پیوسته',
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
                SizedBox(height: metrics.spaceXs),
                Text(
                  '${toPersianDigits(weeks)} هفته',
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
}
