import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo_energy_dial.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// کارت وضعیت انرژی جاری در داشبورد امروز
class EnergyDashboardCard extends StatelessWidget {
  const EnergyDashboardCard({
    super.key,
    required this.isDarkMode,
    required this.currentEnergyPercent,
    required this.currentEnergyLabel,
    required this.currentEnergyDesc,
    required this.onEnergyTap,
  });

  final bool isDarkMode;
  final double? currentEnergyPercent;
  final String currentEnergyLabel;
  final String currentEnergyDesc;
  final VoidCallback onEnergyTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final m = context.metrics;

    final Color energyColor;
    final IconData energyIcon;

    final isHigh = currentEnergyLabel == 'بالا' || currentEnergyLabel == 'High';
    final isLow = currentEnergyLabel == 'پایین' || currentEnergyLabel == 'Low';

    if (isHigh) {
      energyColor = colors.success;
      energyIcon = CupertinoIcons.flame_fill;
    } else if (isLow) {
      energyColor = colors.medicalRed;
      energyIcon = CupertinoIcons.moon_fill;
    } else {
      energyColor = colors.energyAccent;
      energyIcon = CupertinoIcons.bolt_fill;
    }

    final energyLabel = isHigh
        ? l10n.energyLevelHigh
        : isLow
            ? l10n.energyLevelLow
            : l10n.energyLevelMedium;

    final energyDesc = isHigh
        ? l10n.energyDescHigh
        : isLow
            ? l10n.energyDescLow
            : l10n.energyDescMedium;

    return RitmoTheme.glassCardLight(
      color: colors.card.withValues(alpha: 0.65),
      child: InkWell(
        onTap: onEnergyTap,
        borderRadius: BorderRadius.circular(m.radiusHero),
        child: Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(m.radiusHero),
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.3,
              colors: [
                energyColor.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: m.spaceLg,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.currentEnergyTitle,
                    style: RitmoTextStyles.badge(
                      colors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: EdgeInsets.all(m.spaceXs),
                    decoration: BoxDecoration(
                      color: energyColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      energyIcon,
                      size: m.iconSm,
                      color: energyColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: m.spaceMd),
              Row(
                children: [
                  // Modern Thermostat-Style Energy Dial
                  RitmoEnergyDial(
                    percentage: currentEnergyPercent,
                    isDarkMode: isDarkMode,
                    size: 78.0 * m.densityFactor,
                    activeColor: energyColor,
                  ),
                  SizedBox(width: m.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          energyLabel,
                          style: RitmoTextStyles.titleMedium(
                            energyColor,
                          ).copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          energyDesc,
                          style: RitmoTextStyles.badge(
                            colors.textSecondary,
                          ).copyWith(height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: m.spaceMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: m.spaceSm,
                      vertical: m.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(m.radiusCard),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.manageEnergy,
                          style: RitmoTextStyles.badge(
                            colors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          CupertinoIcons.chevron_left,
                          size: m.iconSm * 0.75,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
