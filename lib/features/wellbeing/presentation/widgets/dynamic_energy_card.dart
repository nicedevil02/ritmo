import 'package:flutter/material.dart';
import 'package:ritmo/core/analytics/energy_analytics_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo_progress_ring.dart';

/// کارت نمایش انرژی پویای لحظه‌ای و تفکیک دلایل آن
class DynamicEnergyCard extends StatefulWidget {
  const DynamicEnergyCard({
    super.key,
    required this.output,
    required this.onLogTap,
  });

  final EnergyAnalyticsOutput? output;
  final VoidCallback onLogTap;

  @override
  State<DynamicEnergyCard> createState() => _DynamicEnergyCardState();
}

class _DynamicEnergyCardState extends State<DynamicEnergyCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final out = widget.output;
    final energy = out?.currentDynamicEnergy ?? 0.0;
    final percent = (energy * 100).round().clamp(0, 100);
    final explanations = out?.currentDynamicEnergyExplanations ?? const [];

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
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
                  Icon(Icons.bolt, color: colors.energyAccent, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    'انرژی الانِ من',
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ],
              ),
              if (out?.isAiDerived ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'تخمین هوشمند',
                    style: RitmoTextStyles.caption(colors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: RitmoProgressRing(
                  value: (energy * 100).clamp(0.0, 100.0),
                  size: 64,
                  strokeWidth: 6,
                ),
              ),
              const SizedBox(width: RitmoSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _energyStatusTitle(percent),
                      style: RitmoTextStyles.titleMedium(colors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _energyStatusDescription(percent),
                      style: RitmoTextStyles.caption(colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (explanations.isNotEmpty) ...[
            const SizedBox(height: RitmoSpacing.md),
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'چرا این عدد؟',
                      style: RitmoTextStyles.label(colors.primary),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(RitmoSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: explanations.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: RitmoTextStyles.body(colors.primary)),
                          Expanded(
                            child: Text(
                              e,
                              style: RitmoTextStyles.caption(colors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _energyStatusTitle(int percent) {
    if (percent >= 70) return 'انرژی در اوج ⚡';
    if (percent >= 40) return 'انرژی پایدار و متعادل 🌿';
    if (percent > 0) return 'نیاز به بازیابی و استراحت ☕';
    return 'هنوز ثبت نشده است';
  }

  String _energyStatusDescription(int percent) {
    if (percent >= 70) return 'زمان ایده‌آل برای کارهای عمیق و پرچالش فکری.';
    if (percent >= 40) return 'مناسب برای کارهای روزمره و روتین‌های منظم.';
    if (percent > 0) return 'کارهای سبک‌تر را انتخاب کن و به خودت استراحت بده.';
    return 'با ثبت خواب یا انرژی، سطح لحظه‌ای محاسبه می‌شود.';
  }
}
