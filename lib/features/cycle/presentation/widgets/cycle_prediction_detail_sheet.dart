// C-43, C-44: CyclePredictionDetailSheet
// F-38: Transparent, clinically honest explanation sheet for predicted cycle days.
import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CyclePredictionDetailSheet extends StatelessWidget {
  const CyclePredictionDetailSheet({
    super.key,
    required this.selectedDate,
    required this.mark,
    required this.engineOutput,
    this.symptomForecasts = const [],
    required this.onRecordPeriodFromDate,
  });

  final DateTime selectedDate;
  final CycleDayMark mark;
  final CycleEngineOutput? engineOutput;
  final List<SymptomForecast> symptomForecasts;
  final ValueChanged<DateTime> onRecordPeriodFromDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final jDate = Jalali.fromDateTime(selectedDate);
    final cycle = mark.predictedCycle;
    final isPast = CycleDateContract.isSameOrBefore(
      selectedDate,
      CycleClock.now,
    );

    final String title;
    final IconData icon;
    final Color headerColor;

    switch (mark.kind) {
      case CycleDayKind.predictedPeriod:
        title = 'پیش‌بینی شروع دوره قاعدگی';
        icon = CupertinoIcons.calendar_badge_plus;
        headerColor = colors.error;
        break;
      case CycleDayKind.predictionWindow:
        title = 'بازه احتمالی جابجایی قاعدگی';
        icon = CupertinoIcons.waveform_path_badge_plus;
        headerColor = colors.textSecondary;
        break;
      case CycleDayKind.ovulation:
        title = isPast
            ? 'روز تخمک‌گذاری (دوره گذشته)'
            : 'روز تخمک‌گذاری تخمینی';
        icon = CupertinoIcons.sparkles;
        headerColor = colors.accent;
        break;
      case CycleDayKind.fertileWindow:
        title = isPast ? 'پنجره باروری (دوره گذشته)' : 'پنجره باروری تخمینی';
        icon = CupertinoIcons.heart_circle;
        headerColor = colors.accent;
        break;
      case CycleDayKind.pms:
        title = 'روزهای پیش از عادت (PMS)';
        icon = CupertinoIcons.moon_stars;
        headerColor = colors.primary;
        break;
      default:
        title = 'اطلاعات روز';
        icon = CupertinoIcons.calendar;
        headerColor = colors.primary;
        break;
    }

    final confidenceLevel = mark.confidenceLevel ?? cycle?.confidenceLevel;
    final confidenceLabel = switch (confidenceLevel) {
      PredictionConfidenceLevel.high => 'اطمینان بالا',
      PredictionConfidenceLevel.medium => 'اطمینان متوسط',
      PredictionConfidenceLevel.low => 'اطمینان کم (داده محدود)',
      null => isPast ? 'محاسبه گذشته‌نگر' : 'تخمینی',
    };

    final basisDescription = switch (cycle?.basis) {
      ForecastBasis.measured =>
        'محاسبه‌شده بر اساس میانگین و انحراف معیار چرخه‌های ثبت‌شده شما.',
      ForecastBasis.partiallyMeasured =>
        'محاسبه‌شده با داده‌های محدود اولیه؛ با ثبت چرخه‌های بیشتر دقت افزایش می‌یابد.',
      ForecastBasis.defaultAssumption =>
        'محاسبه‌شده بر اساس تنظیمات پیش‌فرض بالینی، به دلیل نبود چرخه‌های ثبت‌شده کافی.',
      null =>
        isPast
            ? 'محاسبه‌شده گذشته‌نگر بر پایهٔ تاریخ شروع دورهٔ بعدی و فاز لوتئال (Luteal Phase). این بازه بیشترین احتمال باروری چرخه را داشته است.'
            : 'محاسبه‌شده بر اساس الگوهای زمانی.',
    };

    final disclaimer =
        engineOutput?.predictionDisclaimer ??
        'این تاریخ‌ها صرفاً تخمین آماری هستند و نباید به عنوان روش قطعی پیشگیری یا تشخیص پزشکی تلقی شوند.';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
        ),
        child: RitmoGlassSheet(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header Row
                Row(
                  children: [
                    RitmoNeuButton(
                      padding: const EdgeInsets.all(8),
                      radius: 10,
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: headerColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: headerColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: RitmoTextStyles.cardTitle(colors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${RitmoNumber.faInt(jDate.day)} ${jDate.formatter.mN} ${RitmoNumber.faInt(jDate.year)}',
                            style: RitmoTextStyles.caption(colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (confidenceLevel != null)
                      RitmoCardBadge(
                        label: confidenceLabel,
                        color: headerColor,
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Uncertainty Window Range (if cycle available)
                if (cycle != null) ...[
                  RitmoCard.neumorphicSunken(
                    padding: const EdgeInsets.all(12),
                    child: _buildInfoRow(
                      icon: CupertinoIcons.arrow_left_right_circle,
                      title: 'بازه جابجایی احتمالی',
                      value:
                          '${_formatJalaliDate(cycle.windowStart)} تا ${_formatJalaliDate(cycle.windowEnd)}',
                      colors: colors,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Estimation Basis
                RitmoCard.neumorphicSunken(
                  padding: const EdgeInsets.all(12),
                  child: _buildInfoRow(
                    icon: CupertinoIcons.info_circle,
                    title: 'مبنای محاسبه',
                    value: basisDescription,
                    colors: colors,
                  ),
                ),
                const SizedBox(height: 10),

                // Probable Symptoms (if any)
                if (symptomForecasts.isNotEmpty) ...[
                  RitmoCard.neumorphicSunken(
                    padding: const EdgeInsets.all(12),
                    child: _buildInfoRow(
                      icon: CupertinoIcons.heart,
                      title: 'علائم احتمالی بر اساس الگوهای پیشین',
                      value: symptomForecasts
                          .map((s) => _translateSymptom(s.symptomKey))
                          .join('، '),
                      colors: colors,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Clinical Disclaimer (F-38 requirement)
                RitmoCard.neumorphicSunken(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.shield_lefthalf_fill,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          disclaimer,
                          style: RitmoTextStyles.caption(colors.textSecondary).copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // CTA Button: "ثبت شروع دوره از این روز"
                RitmoPrimaryButton(
                  label: 'ثبت شروع قاعدگی از این روز',
                  icon: CupertinoIcons.plus_circle_fill,
                  onPressed: () {
                    Navigator.pop(context);
                    onRecordPeriodFromDate(selectedDate);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required RitmoColors colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: colors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatJalaliDate(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    return '${RitmoNumber.faInt(j.day)} ${j.formatter.mN}';
  }

  static String _translateSymptom(String key) {
    switch (key.toLowerCase()) {
      case 'cramps':
        return 'دل‌درد و انقباض';
      case 'headache':
        return 'سردرد';
      case 'bloating':
        return 'نفخ شکم';
      case 'fatigue':
        return 'خستگی بدنی';
      case 'backache':
        return 'کمردرد';
      case 'mood_swings':
        return 'نوسانات خُلق';
      case 'nausea':
        return 'حالت تهوع';
      case 'tender_breasts':
      case 'breast_tenderness':
        return 'حساسیت سینه‌ها';
      case 'insomnia':
        return 'بی‌خوابی';
      case 'acne':
        return 'جوش پوستی';
      case 'cravings':
        return 'هوس‌های غذایی';
      case 'joint_pain':
        return 'درد مفاصل';
      default:
        return key;
    }
  }
}
