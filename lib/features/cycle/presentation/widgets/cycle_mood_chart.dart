import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';

class CycleMoodChartSection extends StatefulWidget {
  const CycleMoodChartSection({super.key, required this.averageCycleLength});
  final int averageCycleLength;

  @override
  State<CycleMoodChartSection> createState() => _CycleMoodChartSectionState();
}

class _CycleMoodChartSectionState extends State<CycleMoodChartSection> {
  bool _loading = true;
  List<Map<String, dynamic>> _logs = [];
  Map<int, double> _dayMoodAverages = {};
  int _maxAnxietyDay = -1;
  int _maxEnergyDay = -1;

  @override
  void initState() {
    super.initState();
    _loadMoodData();
  }

  Future<void> _loadMoodData() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Get recent cycle periods to map dates to cycle days
      final allPeriods = await CyclePeriodRepository.instance.getAllPeriods(db);
      final periods = allPeriods.take(6).toList();

      if (periods.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // 2. Fetch day logs that have mood or symptoms
      final logs = await db.query('cycle_day_logs', orderBy: 'logDate DESC');
      _logs = logs;

      // 3. Map logs to cycle day (Day 1 to CycleLength)
      final Map<int, List<double>> moodBuckets = {};
      final Map<int, int> anxietyBuckets = {};
      final Map<int, int> energyBuckets = {};

      for (final log in logs) {
        final dateIso = (log['logDate'] ?? log['dateIso']) as String?;
        if (dateIso == null) continue;
        final logDate = CycleDateContract.parseDayKey(dateIso);
        if (logDate == null) continue;

        // Find which period this log belongs to
        DateTime? matchingPeriodStart;
        for (final p in periods) {
          final pStart = p.startDate;

          // A period governs up to widget.averageCycleLength days forward
          final diff = logDate.difference(pStart).inDays;
          if (diff >= 0 && diff < (widget.averageCycleLength + 5)) {
            matchingPeriodStart = pStart;
            break;
          }
        }

        if (matchingPeriodStart != null) {
          final cycleDay = logDate.difference(matchingPeriodStart).inDays + 1;
          if (cycleDay >= 1 && cycleDay <= widget.averageCycleLength) {
            // Extract Mood Value (0 to 4 scale)
            final mood = log['mood'] as String?;
            if (mood != null) {
              final val = _moodToScore(mood);
              if (val != null) {
                moodBuckets.putIfAbsent(cycleDay, () => []).add(val);
                if (mood == 'anxious' || mood == 'sad' || mood == 'tired') {
                  anxietyBuckets[cycleDay] =
                      (anxietyBuckets[cycleDay] ?? 0) + 1;
                } else if (mood == 'energetic' || mood == 'happy') {
                  energyBuckets[cycleDay] = (energyBuckets[cycleDay] ?? 0) + 1;
                }
              }
            }
          }
        }
      }

      // Compute Averages
      final Map<int, double> averages = {};
      moodBuckets.forEach((day, scores) {
        if (scores.isNotEmpty) {
          final avg = scores.reduce((a, b) => a + b) / scores.length;
          averages[day] = avg;
        }
      });

      // Find critical points
      int maxAnxietyD = -1;
      var maxAnxietyCount = 0;
      anxietyBuckets.forEach((day, count) {
        if (count > maxAnxietyCount) {
          maxAnxietyCount = count;
          maxAnxietyD = day;
        }
      });

      int maxEnergyD = -1;
      var maxEnergyCount = 0;
      energyBuckets.forEach((day, count) {
        if (count > maxEnergyCount) {
          maxEnergyCount = count;
          maxEnergyD = day;
        }
      });

      if (mounted) {
        setState(() {
          _dayMoodAverages = averages;
          _maxAnxietyDay = maxAnxietyD;
          _maxEnergyDay = maxEnergyD;
          _loading = false;
        });
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleMoodChartSection] error loading data',
        error: e,
        stack: st,
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _moodToScore(String mood) {
    switch (mood.toLowerCase()) {
      case 'energetic':
      case 'happy':
      case 'calm':
        return 4.0;
      case 'normal':
      case 'fine':
        return 3.0;
      case 'tired':
      case 'moody':
        return 2.0;
      case 'anxious':
      case 'sad':
        return 1.0;
      case 'angry':
      case 'irritated':
        return 0.0;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return RitmoCard.neumorphic(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    if (_logs.length < 5) {
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
                  CupertinoIcons.heart_circle,
                  color: colors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'هنوز در حالِ یادگیریِ الگوی احساست هستم 🌸',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'با ثبتِ روزانه احوال، نمودار دقیق‌تر می‌شود.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }


    return RitmoCard.neumorphic(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RitmoCardHeader(
            title: 'روند تغییرات خلق‌وخو در طول چرخه بدنی',
            subtitle: 'نمودار نوسانات احساسی نسبت به روزهای چرخه',
            icon: CupertinoIcons.heart_circle_fill,
          ),
          const SizedBox(height: 14),
          RitmoNeuSurface(
            sunken: true,
            radius: 16,
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: RepaintBoundary(
              child: SizedBox(
                height: 160,
                child: CustomPaint(
                  painter: _MoodChartPainter(
                    moodAverages: _dayMoodAverages,
                    cycleLength: widget.averageCycleLength,
                    maxAnxietyDay: _maxAnxietyDay,
                    maxEnergyDay: _maxEnergyDay,
                    primaryColor: colors.primary,
                    anxietyColor: colors.error,
                    energyColor: colors.success,
                    textColor: colors.textSecondary,
                    gridColor: colors.border.withValues(alpha: 0.15),
                    criticalTextColor: colors.textPrimary,
                    textScaler: MediaQuery.textScalerOf(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendDot(
                colors.primary,
                'میانگین خلق‌وخو',
                isDark,
                colors,
              ),
              if (_maxAnxietyDay != -1)
                _buildLegendDot(
                  colors.error,
                  'اوج اضطراب (روز ${PersianDigits.toFa(_maxAnxietyDay.toString())})',
                  isDark,
                  colors,
                ),
              if (_maxEnergyDay != -1)
                _buildLegendDot(
                  colors.success,
                  'اوج انرژی (روز ${PersianDigits.toFa(_maxEnergyDay.toString())})',
                  isDark,
                  colors,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(
    Color dotColor,
    String label,
    bool isDark,
    RitmoColors colors,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: RitmoTextStyles.caption(colors.textSecondary),
        ),
      ],
    );
  }
}

class _MoodChartPainter extends CustomPainter {
  _MoodChartPainter({
    required this.moodAverages,
    required this.cycleLength,
    required this.maxAnxietyDay,
    required this.maxEnergyDay,
    required this.primaryColor,
    required this.anxietyColor,
    required this.energyColor,
    required this.textColor,
    required this.gridColor,
    required this.criticalTextColor,
    required this.textScaler,
  });
  final Map<int, double> moodAverages;
  final int cycleLength;
  final int maxAnxietyDay;
  final int maxEnergyDay;
  final Color primaryColor;
  final Color anxietyColor;
  final Color energyColor;
  final Color textColor;
  final Color gridColor;
  final Color criticalTextColor;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    const paddingLeft = 60.0;
    const paddingBottom = 20.0;
    const paddingTop = 12.0;
    const paddingRight = 12.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(
      textDirection: TextDirection.rtl,
      textScaler: textScaler,
    );

    final yLabels = {
      4.0: '😃 عالی',
      3.0: '🙂 خوب',
      2.0: '😐 بی‌حوصله',
      1.0: '😰 مضطرب',
      0.0: '😡 کلافه',
    };

    yLabels.forEach((val, label) {
      final y = paddingTop + chartHeight - (val / 4.0) * chartHeight;
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(fontSize: 8.5, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(paddingLeft - textPainter.width - 6, y - 6),
      );
    });

    final xDays = [
      1,
      (cycleLength / 4).round(),
      (cycleLength / 2).round(),
      (3 * cycleLength / 4).round(),
      cycleLength,
    ];
    for (final day in xDays) {
      final x = paddingLeft + ((day - 1) / (cycleLength - 1)) * chartWidth;
      canvas.drawLine(
        Offset(x, paddingTop),
        Offset(x, paddingTop + chartHeight),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: PersianDigits.toFa('روز $day'),
        style: TextStyle(fontSize: 8.5, color: textColor),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, paddingTop + chartHeight + 4),
      );
    }

    final points = <Offset>[];
    final sortedAverages = moodAverages.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedAverages) {
      final day = entry.key;
      final val = entry.value;
      if (day < 1 || day > cycleLength) continue;

      final x = paddingLeft + ((day - 1) / (cycleLength - 1)) * chartWidth;
      final y = paddingTop + chartHeight - (val / 4.0) * chartHeight;
      points.add(Offset(x, y));
    }

    if (points.isNotEmpty) {
      final fillPath = Path();
      fillPath.moveTo(points.first.dx, paddingTop + chartHeight);
      for (final pt in points) {
        fillPath.lineTo(pt.dx, pt.dy);
      }
      fillPath.lineTo(points.last.dx, paddingTop + chartHeight);
      fillPath.close();

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.18),
          primaryColor.withValues(alpha: 0),
        ],
      );
      fillPaint.shader = gradient.createShader(
        Rect.fromLTWH(paddingLeft, paddingTop, chartWidth, chartHeight),
      );
      canvas.drawPath(fillPath, fillPaint);

      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, linePaint);

      for (final pt in points) {
        dotPaint.color = primaryColor;
        canvas.drawCircle(pt, 3.5, dotPaint);
      }

      if (maxAnxietyDay != -1 && moodAverages.containsKey(maxAnxietyDay)) {
        final val = moodAverages[maxAnxietyDay]!;
        final x =
            paddingLeft +
            ((maxAnxietyDay - 1) / (cycleLength - 1)) * chartWidth;
        final y = paddingTop + chartHeight - (val / 4.0) * chartHeight;

        dotPaint.color = anxietyColor.withValues(alpha: 0.25);
        canvas.drawCircle(Offset(x, y), 8, dotPaint);
        dotPaint.color = anxietyColor;
        canvas.drawCircle(Offset(x, y), 4.5, dotPaint);

        textPainter.text = TextSpan(
          text: 'اوج بی‌حوصلگی 😰',
          style: TextStyle(
            fontSize: 8.5,
            color: anxietyColor,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        final textX = x - textPainter.width / 2;
        const minX = paddingLeft + 4.0;
        final maxX = size.width - textPainter.width - 4.0;

        var labelY = y - 18;
        if (labelY < 2.0) {
          labelY = y + 8.0;
        }

        textPainter.paint(canvas, Offset(textX.clamp(minX, maxX), labelY));
      }

      if (maxEnergyDay != -1 && moodAverages.containsKey(maxEnergyDay)) {
        final val = moodAverages[maxEnergyDay]!;
        final x =
            paddingLeft + ((maxEnergyDay - 1) / (cycleLength - 1)) * chartWidth;
        final y = paddingTop + chartHeight - (val / 4.0) * chartHeight;

        dotPaint.color = energyColor.withValues(alpha: 0.25);
        canvas.drawCircle(Offset(x, y), 8, dotPaint);
        dotPaint.color = energyColor;
        canvas.drawCircle(Offset(x, y), 4.5, dotPaint);

        final isOverlap = (maxAnxietyDay == maxEnergyDay);
        var labelY = isOverlap ? y + 10.0 : y - 18;
        if (labelY < 2.0) {
          labelY = y + 8.0;
        }

        textPainter.text = TextSpan(
          text: 'اوج انرژی ⚡',
          style: TextStyle(
            fontSize: 8.5,
            color: energyColor,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        final textX = x - textPainter.width / 2;
        const minX = paddingLeft + 4.0;
        final maxX = size.width - textPainter.width - 4.0;

        textPainter.paint(canvas, Offset(textX.clamp(minX, maxX), labelY));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
