import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';

class CyclePredictionConfidenceCard extends StatelessWidget {
  const CyclePredictionConfidenceCard({
    super.key,
    required this.confidence,
    required this.dataQuality,
  });

  final PredictionConfidence confidence;
  final DataQualityReport dataQuality;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final badgeColor = switch (confidence.level) {
      PredictionConfidenceLevel.high => Colors.teal,
      PredictionConfidenceLevel.medium => Colors.amber.shade700,
      PredictionConfidenceLevel.low => Colors.orange.shade800,
    };

    final badgeLabelFa = switch (confidence.level) {
      PredictionConfidenceLevel.high => 'اطمینان بالا',
      PredictionConfidenceLevel.medium => 'اطمینان متوسط',
      PredictionConfidenceLevel.low => 'نیازمند داده بیشتر',
    };

    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RitmoCardHeader(
            title: 'اعتبار پیش‌بینی ریتم بدنی',
            subtitle: 'کیفیت داده‌ها و دقت تخمین دوره‌ها',
            icon: Icons.verified_outlined,
            iconColor: badgeColor,
            trailing: RitmoCardBadge(
              label: badgeLabelFa,
              color: badgeColor,
            ),
          ),
          if (confidence.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...confidence.reasons.map(
              (r) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 13,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
