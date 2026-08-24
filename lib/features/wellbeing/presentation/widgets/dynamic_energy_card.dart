import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/analytics/energy_analytics_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';

/// کارت هیرو نمایش انرژی پویای لحظه‌ای، گوی نوری و تفکیک عوامل بیولوژیک
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

    final energyColor = _getEnergyColor(percent, colors);

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(
          color: energyColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: energyColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: Title & AI Badge ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: energyColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.bolt_fill,
                      color: energyColor,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'انرژی الانِ من',
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ],
              ),
              if (out?.isAiDerived ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.sparkles, size: 12, color: colors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'تخمین هوشمند',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // ─── Energy Orb & Status Info ───
          Row(
            children: [
              // Glowing Energy Orb
              _buildEnergyOrb(percent, energyColor, colors),
              const SizedBox(width: RitmoSpacing.lg),

              // Title, Description and Quick Action
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _energyStatusTitle(percent),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: energyColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _energyStatusDescription(percent),
                      style: RitmoTextStyles.caption(colors.textSecondary).copyWith(
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onLogTap();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: energyColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: energyColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.add_circled, size: 14, color: energyColor),
                            const SizedBox(width: 5),
                            Text(
                              'ثبت یا تغییر انرژی',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: energyColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ─── Expandable Explanations ───
          if (explanations.isNotEmpty) ...[
            const SizedBox(height: RitmoSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isExpanded = !_isExpanded);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.info_circle,
                          size: 15,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'عوامل مؤثر بر این عدد (${RitmoNumber.faInt(explanations.length)} عامل)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      _isExpanded
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      size: 15,
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
                  color: colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: explanations.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6, left: 6),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: energyColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.textPrimary,
                                height: 1.4,
                              ),
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

  Widget _buildEnergyOrb(int percent, Color energyColor, RitmoColors colors) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer ambient glow ring
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                energyColor.withValues(alpha: 0.25),
                energyColor.withValues(alpha: 0.02),
              ],
            ),
          ),
        ),
        // Inner Glass Circle
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: energyColor.withValues(alpha: 0.45),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: energyColor.withValues(alpha: 0.2),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                RitmoNumber.faInt(percent),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: energyColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'از ۱۰۰',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getEnergyColor(int percent, RitmoColors colors) {
    if (percent >= 75) return const Color(0xff10B981); // Emerald Green
    if (percent >= 45) return const Color(0xffF59E0B); // Amber/Golden
    return const Color(0xffEC4899); // Rose/Magenta
  }

  String _energyStatusTitle(int percent) {
    if (percent >= 80) return 'انرژی در اوج ⚡';
    if (percent >= 60) return 'انرژی مطلوب و پایدار';
    if (percent >= 40) return 'انرژی متوسط';
    if (percent >= 20) return 'افت تدریجی انرژی';
    return 'نیاز فوری به بازیابی و استراحت';
  }

  String _energyStatusDescription(int percent) {
    if (percent >= 80) {
      return 'زمان ایده‌آل برای کارهای عمیق، تصمیم‌گیری‌های کلیدی و چالش‌های فکری سنگین.';
    }
    if (percent >= 60) {
      return 'توان و تمرکز در وضعیت مناسب برای پیشبرد فعالیت‌های اصلی و روتین‌های روزانه.';
    }
    if (percent >= 40) {
      return 'سطح توان متوسط؛ مناسب برای وظایف با پیچیدگی معمولی یا اداری.';
    }
    if (percent >= 20) {
      return 'بدن شما نشانه‌های خستگی را نشان می‌دهد؛ نوشیدن آب و کمی کشش پیشنهاد می‌شود.';
    }
    return 'خستگی ملموس؛ استراحت کوتاه، تنفس عمیق یا خواب نیمروزی برای شارژ مجدد ضروری است.';
  }
}
