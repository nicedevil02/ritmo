import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'پیش‌بینی الگوهای شخصی',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...forecasts.map(
            (f) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      f.insightFa ??
                          'احتمال بروز ${_translateSymptom(f.symptomKey)} در این بازه',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
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
