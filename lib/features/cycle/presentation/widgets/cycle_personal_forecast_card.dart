import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';

class CyclePersonalForecastCard extends StatelessWidget {
  const CyclePersonalForecastCard({super.key, required this.forecasts});

  final List<SymptomForecast> forecasts;

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
        return 'حساسیت سینه‌ها';
      case 'insomnia':
        return 'بی‌خوابی';
      case 'acne':
        return 'جوش پوستی';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (forecasts.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;

    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RitmoCardHeader(
            title: 'پیش‌بینی الگوهای شخصی',
            subtitle: 'بر اساس علائم و تجربیات ثبت‌شده شما',
            icon: Icons.psychology_outlined,
            iconColor: colors.primary,
          ),
          const SizedBox(height: 10),
          ...forecasts.map(
            (f) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f.insightFa ??
                          'احتمال بروز ${_translateSymptom(f.symptomKey)} در این بازه',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
