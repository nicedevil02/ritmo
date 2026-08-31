import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/logic/cycle_correlation.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';

class CycleCorrelationSection extends StatefulWidget {
  const CycleCorrelationSection({super.key});

  @override
  State<CycleCorrelationSection> createState() =>
      _CycleCorrelationSectionState();
}

class _CycleCorrelationSectionState extends State<CycleCorrelationSection> {
  bool _loading = true;
  List<CycleCorrelation> _correlations = [];

  @override
  void initState() {
    super.initState();
    _loadCorrelations();
  }

  Future<void> _loadCorrelations() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final corrs = await CycleCorrelationAnalyzer.analyzeCorrelations(db);
      if (mounted) {
        setState(() {
          _correlations = corrs;
          _loading = false;
        });
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleCorrelationSection] error loading correlations',
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

  String _toPersianDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = input;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }
    return result;
  }

  String _translateMetric(String metric) {
    switch (metric.toLowerCase()) {
      case 'energy':
        return 'سطح انرژی روزانه';
      case 'sleep':
        return 'کیفیت و الگوی خواب';
      case 'routines':
        return 'پایبندی به روتین‌ها و عادات';
      default:
        return metric;
    }
  }

  String _translateInsight(String insight) {
    switch (insight.toLowerCase()) {
      case 'insufficient_data':
        return 'تعداد روزهای ثبت‌شده برای محاسبهٔ همبستگی کافی نیست (حداقل ۱۴ روز).';
      case 'no_variance':
        return 'تغییرات آماری ثبت‌شده برای سنجش همبستگی یکنواخت است.';
      case 'not_significant':
        return 'ارتباط آماری معناداری بین شدت علائم چرخه و این شاخص مشاهده نشد.';
      case 'negative_correlation':
        return 'با افزایش شدت علائم چرخه، این شاخص کاهش می‌یابد.';
      case 'positive_correlation':
        return 'نوسانات این شاخص همسو با تغییرات فازهای چرخه است.';
      case 'neutral':
        return 'این شاخص در طول روزهای چرخه نسبتاً پایدار و بدون نوسان بوده است.';
      default:
        return insight;
    }
  }

  IconData _getMetricIcon(String metric) {
    switch (metric.toLowerCase()) {
      case 'energy':
        return CupertinoIcons.bolt_fill;
      case 'sleep':
        return CupertinoIcons.moon_fill;
      case 'routines':
        return CupertinoIcons.checkmark_seal_fill;
      default:
        return CupertinoIcons.chart_bar_square_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (_correlations.isEmpty) {
      return RitmoCard.neumorphic(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RitmoNeuSurface(
                sunken: true,
                radius: 24,
                padding: const EdgeInsets.all(16),
                child: Icon(
                  CupertinoIcons.chart_pie,
                  color: colors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'هنوز داده‌های کافی برای تحلیل همبستگی ثبت نشده است',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'حداقل به ثبت ۱۴ روز لاگ روزانه نیاز است.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Disclaimer Banner
        RitmoNeuSurface(
          sunken: true,
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          tint: colors.warning.withValues(alpha: isDark ? 0.08 : 0.05),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.warning.withValues(alpha: isDark ? 0.22 : 0.15),
                ),
                child: Icon(
                  CupertinoIcons.info,
                  color: colors.warning,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'توجه: همبستگی‌های نمایش داده شده صرفاً آماری بوده و به معنی رابطه علّی و معلولی قطعی نیست.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // List of correlations
        ..._correlations.map((corr) {
          final coeff = corr.coefficient;
          final hasCoeff = coeff != null;

          Color indicatorColor = colors.textSecondary;
          var strengthText = 'داده کافی نیست';
          if (hasCoeff) {
            if (coeff.abs() > 0.6) {
              indicatorColor = colors.primary;
              strengthText = coeff > 0
                  ? 'همبستگی مستقیم قوی'
                  : 'همبستگی معکوس قوی';
            } else if (coeff.abs() > 0.3) {
              indicatorColor = colors.warning;
              strengthText = coeff > 0
                  ? 'همبستگی مستقیم ملایم'
                  : 'همبستگی معکوس ملایم';
            } else {
              indicatorColor = colors.success;
              strengthText = 'بدون نوسان همبسته';
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: RitmoCard.neumorphic(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getMetricIcon(corr.metric),
                            color: colors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _translateMetric(corr.metric),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      RitmoCardBadge(
                        label: strengthText,
                        color: indicatorColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  if (hasCoeff)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            'ضریب پیرسون: ',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colors.textSecondary,
                            ),
                          ),
                          Text(
                            _toPersianDigits(coeff.toStringAsFixed(2)),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    _translateInsight(corr.insight),
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
        }),
      ],
    );
  }
}
