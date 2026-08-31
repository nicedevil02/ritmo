// C-41, C-43, C-45: CycleTrendsSection
// Theme tokens, Persian digits, in-progress ongoing cycle handling, and uncertainty indicators.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_correlation.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_mood_chart.dart';

class CycleTrendsSection extends StatefulWidget {
  const CycleTrendsSection({required this.engineOutput, super.key});
  final CycleEngineOutput engineOutput;

  @override
  State<CycleTrendsSection> createState() => _CycleTrendsSectionState();
}

class _CycleTrendsSectionState extends State<CycleTrendsSection> {
  bool _loading = true;
  List<SymptomStat> _symptomStats = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final stats = await CycleCorrelationAnalyzer.analyzeSymptomStats(db);
      if (mounted) {
        setState(() {
          _symptomStats = stats;
          _loading = false;
        });
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleTrendsSection] error loading symptom stats',
        error: e,
        stack: st,
      );
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _translateSymptom(String key) {
    final lowerKey = key.toLowerCase();
    switch (lowerKey) {
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
      default:
        if (key.length > 1) {
          return key[0].toUpperCase() + key.substring(1).toLowerCase();
        }
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trendPoints = widget.engineOutput.trendPoints;

    if (trendPoints.length < 2) {
      return RitmoNeuSurface(
        sunken: true,
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: isDark ? 0.18 : 0.12),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  CupertinoIcons.sparkles,
                  color: colors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'هنوز در حالِ یادگیریِ الگوی بدنتم 🌸',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'برای مشاهده نمودارهای روند و نظم چرخه، باید حداقل اطلاعات ۲ دوره قبلی را ثبت کرده باشید.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final regularityLabelFa = switch (widget.engineOutput.regularityLevel) {
      RegularityLevel.regular => 'کاملاً منظم',
      RegularityLevel.moderate => 'نسبتاً منظم',
      RegularityLevel.irregular => 'نامنظم',
      RegularityLevel.insufficientData => 'داده ناکافی',
      RegularityLevel.pregnancy => 'دوران بارداری',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Uncertainty & Outlier Notice (C-45)
        if (widget.engineOutput.discardedOutliers > 0 ||
            widget.engineOutput.isProjected)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RitmoNeuSurface(
              sunken: true,
              radius: 16,
              tint: colors.warning.withValues(alpha: isDark ? 0.14 : 0.08),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.info_circle_fill,
                    color: colors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.engineOutput.isProjected
                          ? 'پیش‌بینی‌ها بر مبنای تنظیمات اولیه است.'
                          : '${PersianDigits.toFa(widget.engineOutput.discardedOutliers.toString())} دوره غیرمعمول برای دقت بیشتر از محاسبات آماری کنار گذاشته شدند.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 1. Regularity Score Card
        RitmoCard.neumorphic(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RitmoCardHeader(
                title: 'وضعیت نظم چرخه بدنی',
                subtitle: 'سنجش آماری ثبات طول دوره‌ها',
                icon: CupertinoIcons.chart_bar_alt_fill,
                trailing: RitmoCardBadge(
                  label: regularityLabelFa,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.engineOutput.regularityLevel ==
                        RegularityLevel.irregular
                    ? 'بر اساس تحلیل داده‌های شما، طول چرخه‌ها دارای پراکندگی است. این یک تشخیص پزشکی نیست، اما روتین منظم‌تر به پایداری ریتم بدنی کمک می‌کند.'
                    : widget.engineOutput.regularityLevel ==
                              RegularityLevel.moderate ||
                          widget.engineOutput.regularityLevel ==
                              RegularityLevel.regular
                    ? 'بر اساس تحلیل داده‌های شما، طول چرخه‌های اخیر به هم نزدیک بوده و ریتم بدنی منظم است 🌸'
                    : 'برای محاسبه وضعیت نظم چرخه، نیاز به ثبت دوره‌های بیشتری است.',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Trend Line Chart Card
        RitmoCard.neumorphic(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RitmoCardHeader(
                title: 'نمودار روند طول چرخه‌های اخیر',
                subtitle: 'مقایسه طول دوره با طول کل چرخه',
                icon: CupertinoIcons.waveform_path_ecg,
              ),
              const SizedBox(height: 14),
              RitmoNeuSurface(
                sunken: true,
                radius: 16,
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: SizedBox(
                  height: 150,
                  child: CustomPaint(
                    painter: _CycleTrendPainter(
                      trendPoints: trendPoints,
                      primaryColor: colors.primary,
                      periodColor: colors.error,
                      textColor: colors.textSecondary,
                      gridColor: colors.border.withValues(alpha: 0.15),
                      isDark: isDark,
                    ),
                    child: Container(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendDot(
                    colors.primary,
                    'طول چرخه بدنی (روز)',
                    colors,
                  ),
                  const SizedBox(width: 24),
                  _buildLegendDot(colors.error, 'طول دوره (روز)', colors),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        CycleMoodChartSection(
          averageCycleLength: widget.engineOutput.stats.avgCycleLength.round(),
        ),
        const SizedBox(height: 14),

        // 3. Symptom Stats Card
        RitmoCard.neumorphic(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RitmoCardHeader(
                title: 'بیشترین علائم فیزیکی گزارش‌شده',
                subtitle: 'تکرار شایع‌ترین نشانه‌ها در روزهای چرخه',
                icon: CupertinoIcons.heart_fill,
              ),
              const SizedBox(height: 14),
              if (_loading)
                Center(
                  child: CircularProgressIndicator(color: colors.primary),
                )
              else
                _symptomStats.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'علائمی ثبت نشده است.',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _symptomStats.take(5).length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final maxCount = _symptomStats.first.count;
                          final item = _symptomStats[index];
                          final pct = maxCount > 0
                              ? (item.count / maxCount)
                              : 0.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _translateSymptom(item.key),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  RitmoCardBadge(
                                    label: PersianDigits.toFa(
                                      'روزِ شایع: ${item.typicalCycleDay} · ${item.count} بار',
                                    ),
                                    color: colors.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Visual relative frequency bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  backgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.05),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colors.primary,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label, RitmoColors colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _CycleTrendPainter extends CustomPainter {
  _CycleTrendPainter({
    required this.trendPoints,
    required this.primaryColor,
    required this.periodColor,
    required this.textColor,
    required this.gridColor,
    required this.isDark,
  });

  final List<CycleTrendPoint> trendPoints;
  final Color primaryColor;
  final Color periodColor;
  final Color textColor;
  final Color gridColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (trendPoints.isEmpty) return;

    const paddingLeft = 32.0;
    const paddingRight = 16.0;
    const paddingTop = 16.0;
    const paddingBottom = 24.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;

    final cycleLinePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final periodLinePaint = Paint()
      ..color = periodColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cycleDotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final periodDotPaint = Paint()
      ..color = periodColor
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(textDirection: TextDirection.rtl);

    // Grid horizontal lines (e.g. 20, 28, 35 days)
    final yValues = [10, 20, 28, 35, 45];
    for (final yVal in yValues) {
      final y = paddingTop + chartHeight - (yVal / 50.0) * chartHeight;
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: PersianDigits.toFa(yVal.toString()),
        style: TextStyle(fontSize: 9, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(paddingLeft - textPainter.width - 6, y - 5),
      );
    }

    final cyclePoints = <Offset>[];
    final periodPoints = <Offset>[];

    final n = trendPoints.length;
    for (var i = 0; i < n; i++) {
      final p = trendPoints[i];
      final x = n == 1
          ? paddingLeft + chartWidth / 2
          : paddingLeft + (i / (n - 1)) * chartWidth;

      final cyY =
          paddingTop + chartHeight - (p.lengthDays / 50.0) * chartHeight;
      final perY =
          paddingTop + chartHeight - (p.periodDays / 50.0) * chartHeight;

      cyclePoints.add(Offset(x, cyY));
      periodPoints.add(Offset(x, perY));

      // X label
      textPainter.text = TextSpan(
        text: PersianDigits.toFa(p.index.toString()),
        style: TextStyle(fontSize: 9, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, paddingTop + chartHeight + 6),
      );
    }

    // Draw lines
    if (cyclePoints.length > 1) {
      final cyclePath = Path()
        ..moveTo(cyclePoints.first.dx, cyclePoints.first.dy);
      for (var i = 1; i < cyclePoints.length; i++) {
        cyclePath.lineTo(cyclePoints[i].dx, cyclePoints[i].dy);
      }
      canvas.drawPath(cyclePath, cycleLinePaint);

      final periodPath = Path()
        ..moveTo(periodPoints.first.dx, periodPoints.first.dy);
      for (var i = 1; i < periodPoints.length; i++) {
        periodPath.lineTo(periodPoints[i].dx, periodPoints[i].dy);
      }
      canvas.drawPath(periodPath, periodLinePaint);
    }

    // Draw dots
    for (var i = 0; i < cyclePoints.length; i++) {
      final p = trendPoints[i];
      if (p.isInProgress) {
        // Hollow / semi-transparent dot for in-progress cycle
        canvas.drawCircle(
          cyclePoints[i],
          4.5,
          Paint()
            ..color = primaryColor.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      } else {
        canvas.drawCircle(cyclePoints[i], 3.5, cycleDotPaint);
      }
      canvas.drawCircle(periodPoints[i], 3.0, periodDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
