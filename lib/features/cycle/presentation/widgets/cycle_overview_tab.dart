// C-43, C-44: CycleOverviewTab
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_status.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_confirmation_models.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_orb_card.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_status_banner.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_workout_card.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CycleOverviewTab extends StatelessWidget {
  const CycleOverviewTab({
    super.key,
    required this.engineOutput,
    required this.periods,
    required this.settings,
    required this.forgottenPeriod,
    required this.symptomStats,
    required this.activePhaseColor,
    required this.onTogglePeriodToday,
    required this.onOpenDailyLog,
    required this.onCloseForgottenPeriod,
    required this.onEditPeriod,
    this.isTogglingPeriod = false,
    this.pendingConfirmation,
    this.onOpenConfirmation,
  });

  final CycleEngineOutput? engineOutput;
  final List<Map<String, dynamic>> periods;
  final Map<String, String> settings;
  final Map<String, dynamic>? forgottenPeriod;
  final List<SymptomStat> symptomStats;
  final Color activePhaseColor;
  final VoidCallback onTogglePeriodToday;
  final VoidCallback onOpenDailyLog;
  final ValueChanged<Map<String, dynamic>> onCloseForgottenPeriod;
  final ValueChanged<Map<String, dynamic>> onEditPeriod;
  final bool isTogglingPeriod;
  final CycleConfirmationRequest? pendingConfirmation;
  final VoidCallback? onOpenConfirmation;

  String _formatJalaliDate(DateTime? dt) {
    if (dt == null) return '';
    final jal = Jalali.fromDateTime(dt);
    return '${PersianDigits.toFa(jal.year.toString())}/${PersianDigits.toFa(jal.month.toString().padLeft(2, '0'))}/${PersianDigits.toFa(jal.day.toString().padLeft(2, '0'))}';
  }

  String _formatIsoToJalali(String iso) {
    final dt = CycleDateContract.parseDayKey(iso);
    if (dt == null) return iso;
    final jal = Jalali.fromDateTime(dt);
    return '${PersianDigits.toFa(jal.year.toString())}/${PersianDigits.toFa(jal.month.toString().padLeft(2, '0'))}/${PersianDigits.toFa(jal.day.toString().padLeft(2, '0'))}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final today = CycleClock.now;
    final periodModels = periods.map((p) => CyclePeriod.fromMap(p)).toList();
    final isTodayPeriod = CyclePeriodStatus.isConfirmedPeriodDay(
      periodModels,
      today,
      today,
    );
    final activePeriodDay = CyclePeriodStatus.activeDayNumber(
      periodModels,
      today,
    );
    final phase = engineOutput?.currentPhase ?? CyclePhase.noData;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (engineOutput != null)
          CycleStatusBanner(
            engineOutput: engineOutput!,
            pendingRequest: pendingConfirmation,
            onOpenConfirmation: onOpenConfirmation ?? () {},
            onCloseForgottenPeriod: forgottenPeriod != null
                ? () => onCloseForgottenPeriod(forgottenPeriod!)
                : null,
          ),
        if (forgottenPeriod != null && pendingConfirmation == null) ...[
          _buildForgottenPeriodWarning(context, colors, isDark),
          const SizedBox(height: 6),
        ],
        CycleOrbCard(
          phase: phase,
          isTodayPeriod: isTodayPeriod,
          activePeriodDay: activePeriodDay ?? 0,
          dayOfCycle: engineOutput?.dayOfCycle ?? 1,
          totalCycleLength: engineOutput?.stats.avgCycleLength ?? 28.0,
          avgPeriodDuration:
              engineOutput?.stats.avgPeriodDuration ??
              CycleSettings.getPeriodDuration(settings).toDouble(),
        ),
        const SizedBox(height: 6),
        _buildNextPeriodPredictionCard(context, colors, isDark),
        const SizedBox(height: 6),
        _buildQuickActionButtons(context, colors, isDark),
        const SizedBox(height: 6),
        CycleWorkoutCard(phase: phase),
        const SizedBox(height: 6),
        Builder(
          builder: (ctx) {
            final card = _buildSymptomPredictionCard(ctx, colors, isDark);
            return card != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: card,
                  )
                : const SizedBox();
          },
        ),
        _buildIrregularityStatsCard(context, colors, isDark),
      ],
    );
  }

  Widget _buildForgottenPeriodWarning(
    BuildContext context,
    RitmoColors colors,
    bool isDark,
  ) {
    final startStr = forgottenPeriod!['startDate'] as String;
    final jalaliDateStr = _formatIsoToJalali(startStr);

    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: colors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'دوره قاعدگی باز (احتمالاً فراموش‌شده)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'دوره‌ای که در تاریخ $jalaliDateStr شروع شده، هنوز پایانی برای آن ثبت نشده است (بیش از ۱۲ روز). برای دقت محاسبات چرخه، لطفاً پایان آن را ثبت کنید یا تاریخ‌ها را ویرایش کنید.',
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => onCloseForgottenPeriod(forgottenPeriod!),
                    child: Text(
                      'ثبت پایان (${PersianDigits.toFa(CycleSettings.getPeriodDuration(settings).toString())} روزه)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => onEditPeriod(forgottenPeriod!),
                    child: const Text(
                      'ویرایش تاریخ‌ها',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextPeriodPredictionCard(
    BuildContext context,
    RitmoColors colors,
    bool isDark,
  ) {
    if (engineOutput == null) return const SizedBox();

    final hasEnoughData = engineOutput!.stats.totalRecordedCycles >= 2;
    final predictedDateStr = _formatJalaliDate(
      engineOutput!.nextPeriodPrediction,
    );

    var windowText = '';
    if (hasEnoughData) {
      final startStr = _formatJalaliDate(engineOutput!.nextPeriodWindowStart);
      final endStr = _formatJalaliDate(engineOutput!.nextPeriodWindowEnd);
      windowText = 'بازهٔ تخمینی شروع: از $startStr تا $endStr';
    } else {
      windowText = 'بازهٔ تخمینی: دادهٔ ناکافی جهت محاسبه بازه';
    }

    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.calendar_circle,
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'پیش‌بینی شروع دوره بعدی',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'تاریخ تخمینی شروع: $predictedDateStr',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              windowText,
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'وضعیت ریتم چرخه: ',
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    engineOutput!.regularityLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ),
            Divider(color: colors.border, height: 20),
            Text(
              engineOutput!.predictionDisclaimer,
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons(
    BuildContext context,
    RitmoColors colors,
    bool isDark,
  ) {
    if (engineOutput == null) return const SizedBox();
    final periodModels = periods.map((p) => CyclePeriod.fromMap(p)).toList();
    final shouldOfferEnd = CyclePeriodStatus.shouldOfferEnd(
      periodModels,
      CycleClock.now,
    );

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: isTogglingPeriod ? null : onTogglePeriodToday,
            child: Opacity(
              opacity: isTogglingPeriod ? 0.6 : 1.0,
              child: RitmoTheme.glassCardLight(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: isTogglingPeriod
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: activePhaseColor,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              shouldOfferEnd
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.add_circled_solid,
                              color: activePhaseColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              shouldOfferEnd
                                  ? 'ثبت پایان قاعدگی'
                                  : 'ثبت شروع قاعدگی',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onOpenDailyLog,
            child: RitmoTheme.glassCardLight(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.pencil_outline,
                      color: activePhaseColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ثبت احوال امروز',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildSymptomPredictionCard(
    BuildContext context,
    RitmoColors colors,
    bool isDark,
  ) {
    if (engineOutput == null ||
        !engineOutput!.hasData ||
        symptomStats.isEmpty) {
      return null;
    }

    final currentDay = engineOutput!.dayOfCycle;
    if (currentDay <= 0) return null;

    final upcomingSymptoms = <SymptomStat>[];
    for (final stat in symptomStats) {
      final diff = stat.typicalCycleDay - currentDay;
      if (diff >= 1 && diff <= 3) {
        upcomingSymptoms.add(stat);
      }
    }

    if (upcomingSymptoms.isEmpty) return null;

    final symptomsText = upcomingSymptoms
        .map((s) {
          final diff = s.typicalCycleDay - currentDay;
          return '${s.key} (${diff == 1 ? "فردا" : "در $diff روز آینده"})';
        })
        .join(' و ');

    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(CupertinoIcons.bell_fill, color: colors.warning, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'احتمال بروز علائم در روزهای آینده ⚠️',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'بر اساس الگوهای قبلی، احتمالاً $symptomsText را تجربه کنید.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'توصیه خودمراقبتی: آب بیشتری بنوشید، از غذاهای شور بپرهیزید و روتین خواب و پیاده‌روی سبک را منظم نگه‌دارید. 🌸',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.warning,
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
  }

  Widget _buildIrregularityStatsCard(
    BuildContext context,
    RitmoColors colors,
    bool isDark,
  ) {
    if (engineOutput == null) return const SizedBox();

    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.graph_square,
                  color: colors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'آمار و ریتم بیولوژیک',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatPill(
                  colors,
                  'طول چرخه بدنی',
                  '${PersianDigits.toFa(engineOutput!.stats.avgCycleLength.toStringAsFixed(1))} روز',
                ),
                _buildStatPill(
                  colors,
                  'طول قاعدگی',
                  '${PersianDigits.toFa(engineOutput!.stats.avgPeriodDuration.toStringAsFixed(1))} روز',
                ),
                _buildStatPill(
                  colors,
                  'کل دوره‌ها',
                  PersianDigits.toFa(
                    engineOutput!.stats.totalRecordedCycles.toString(),
                  ),
                ),
              ],
            ),
            if (engineOutput!.isIrregular) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.warning.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_triangle_fill,
                      color: colors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'نوسان در طول چرخه‌ها مشاهده شد. این موضوع غالباً طبیعی است؛ در صورت تداوم می‌توانید آن را با پزشک متخصص مطرح کنید.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.warning,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(RitmoColors colors, String title, String val) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}
