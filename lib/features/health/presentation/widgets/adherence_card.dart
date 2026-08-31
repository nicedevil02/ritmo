import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/health/models/health_models.dart';

class AdherenceCard extends StatelessWidget {
  const AdherenceCard({
    super.key,
    required this.stats,
    this.hasData = true,
  });
  final AdherenceStats stats;

  /// Whether any dose actually came due in the analysed window.
  ///
  /// MED-06: adherence of 0 has two completely different meanings — "you missed
  /// everything" and "there is nothing to measure yet". Rendering the second as
  /// the first blames the user for something they never did, which is the last
  /// thing a health app should do. Defaults to true so existing call sites keep
  /// their current behaviour.
  final bool hasData;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ratePct = stats.adherenceRate * 100;

    // Pick encouraging message based on rate
    var message = '';
    if (ratePct >= 90) {
      message = 'فوق‌العاده است! تعهد شما به سلامت خود بی‌نظیر است. به همین روال ادامه دهید! 🌟';
    } else if (ratePct >= 70) {
      message = 'پیشرفت بسیار خوبی دارید. تلاش شما برای حفظ نظم شایسته تقدیر است. 💪';
    } else if (ratePct >= 50) {
      message = 'هر قدم کوچک به سمت مصرف منظم، شما را به سلامتی نزدیک‌تر می‌کند. صبور باشید و ادامه دهید. 🌱';
    } else {
      message = 'شروع مجدد همیشه ممکن است. با تنظیم یادآورهای دقیق‌تر، می‌توانیم این آمار را در روزهای آینده ارتقا دهیم. ما در کنار شما هستیم. ❤️';
    }

    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RitmoCardHeader(
            title: 'پایبندی به داروها',
            icon: CupertinoIcons.chart_pie_fill,
            iconColor: colors.primary,
            trailing: hasData
                ? RitmoCardBadge(
                    label: _toPersianDigits('${ratePct.toStringAsFixed(0)}٪'),
                    color: ratePct >= 80
                        ? colors.success
                        : (ratePct >= 50 ? colors.warning : colors.medicalRed),
                  )
                : null,
          ),
          const RitmoCardDivider(),
          if (!hasData)
            Row(
              children: [
                Icon(CupertinoIcons.capsule, color: colors.textSecondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'هنوز دُز سررسیدشده‌ای ثبت نشده است. با اولین ثبت مصرف، درصد پایبندی و زنجیره‌ها همین‌جا نمایش داده می‌شود.',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.5),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                // Circular progress ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        value: stats.adherenceRate,
                        backgroundColor: colors.border.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ratePct >= 80
                              ? colors.success
                              : (ratePct >= 50 ? colors.warning : colors.medicalRed),
                        ),
                        strokeWidth: 7,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _toPersianDigits('${ratePct.toStringAsFixed(0)}٪'),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        ),
                        Text(
                          'پایبندی',
                          style: TextStyle(fontSize: 9, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Streaks and details
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.flame_fill, color: colors.warning, size: 16),
                              const SizedBox(width: 6),
                              Text('زنجیره فعلی:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                            ],
                          ),
                          Text(
                            _toPersianDigits('${stats.currentStreak} روز پیاپی'),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.star_fill, color: colors.primary, size: 16),
                              const SizedBox(width: 6),
                              Text('بهترین زنجیره:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                            ],
                          ),
                          Text(
                            _toPersianDigits('${stats.longestStreak} روز'),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (stats.missedPattern != null) ...[
              const RitmoCardDivider(),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.warning.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.lightbulb, color: colors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 11, color: colors.textPrimary),
                          children: [
                            const TextSpan(text: 'الگوی فراموشی: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: stats.missedPattern),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const RitmoCardDivider(),
            Text(
              message,
              style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.5),
              textAlign: TextAlign.justify,
            ),
          ],
        ],
      ),
    );
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
}

